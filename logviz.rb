#
# given a set of columns, assign tag to each
#
require 'rubygems'; require 'ruby-debug'
require 'getoptlong'
require 'json'

$:.unshift(File.dirname(__FILE__))
require 'tokenize'

# use this later to disable debugger
def nothing; end

include Tokenize
include Math        # convenience for expressions...

method = :columns
column_delimiter = ' '
timeseries = nil

labels = {}
raw_exprs = {}
exprs = {}
json = {}
regexps_defined = {}
regexps = {}
rulesfile = nil
title = nil

x_axis = {}
y_axis = {}
y2_axis = {}

datafile = nil
debug = nil
quiet = nil
run_gnuplot = nil
gnuplot_cmd_file = nil
output_data_file = nil
imgfile = nil


#
# data extraction directives
#

# ignore
comment_rx = /\s*\#/

#
# global settings
#

# "DELIMITER some-regex-or-character"
delimiter_rx = /\s*DELIMITER\s+(.*)/i

# "TIMESERIES true-or-false" 
timeseries_rx = /\s*TIMESERIES\s+(\w+)/i 

# "REGEXP some-tag some-regexp"
regexp_define_rx = /\s*REGEXP\s+(\w+)\s*=\s*(.+)/i 

# "TITLE the-title"
title_rx = /\s*TITLE\s+(.+)/i 


#
# labels
#

# "COLUMN some-tag some-column"
column_rx = /\s*COLUMN\s+(\w+)\s+(\d+)/i

# "EXPR some-tag some-expr"
expr_rx = /\s*EXPR\s+(\w+)\s+(.+)/i

# "JSON some-tag json-expr"
json_rx = /\s*JSON\s+(\w+)\s+(.+)/i

# this label applies to the match-indexth capture or regexp-tag
# "MATCH some-tag regexp-tag match-index 
regexp_rx = /\s*MATCH\s+(\w+)\s+(\w+)\s+(\d+)/i


#
# gnuplot directives
#

# "XAXIS some-tag label 
x_rx = /\s*xaxis\s+(\w+)\s+(.*)/i

# "YAXIS some-tag label
y_rx = /\s*yaxis\s+(\w+)\s+(.*)/i

# "Y2AXIS some-tag label
y2_rx = /\s*y2axis\s+(\w+)\s+(.*)/i

# "FILE image-file-name"
imgfile_rx = /\s*file\s+(.+)/i


def looks_like_date(x)
  rv = nil
  begin
    rv = DateTime.parse(x)
  rescue
    puts "not a date: #{x}"
    nil
  end
  rv
end

def ensure_quoted_string(s)
  s = "\"#{s}\"" if not s.match /^('|").*('|")$/
  s
end


#
# main begins
#

def usage
  puts <<-EOF
Generate gnuplot source for an arbitary row-oriented data set.
Usage:
    #{$0} --file <rules-file> --datafile <data-file> [--columns | --json] --gnuplot <cmd-file> --output <output-file> --imagefile <image-file> --run --quiet --DEBUG
  
    In the absence of --datafile, STDIN is read.
    In the absence of --gnuplot, the command file is written to 'gnuplot.cmd' in the local directory.
    In the absence of --output, the output data file is written to 'out' in the local directory.
    Gnuplot will be executed if --run is set.
    Gnuplot will output to tty unless --imagefile is set.

    Column input may be processed either with a fixed delimiter expression or using regexps.
    JSON input is assumed to be an array containing one hash per row. 

    X-axis may be timeseries (date/time format calculated automatically) or just data.

    Rules-file format:
      TIMESERIES [ "true" | "false" ]
      DELIMITER [ <regexp> | <character> ]
      REGEXP <tag> <regexp>

      LABEL <tag> COLUMN <col-num>    # Assign tag to a column in the input data
      LABEL <tag> EXPR <expr>         # Assign tag to an arbitrary expression (can contain defined tags)
      LABEL <tag> JSON <json-expr>    # Assign tag to a JSON expression against current "row"

      XAXIS <tag> <label>             # Set x-axis data set to tag (exactly one required)
      YAXIS <tag> <label>             # Set y-axis data set to tag (one or more)
  EOF
end

opts = GetoptLong.new(
      [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
      [ '--file', '-f', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--columns', '-c', GetoptLong::NO_ARGUMENT ],
      [ '--json', '-j', GetoptLong::NO_ARGUMENT ],
      [ '--run', '-r', GetoptLong::NO_ARGUMENT ],
      [ '--datafile', '-d', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--gnuplot', '-g', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--output', '-o', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--imagefile', '-i', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--quiet', '-q', GetoptLong::NO_ARGUMENT ],
      [ '--DEBUG', '-D', GetoptLong::NO_ARGUMENT ]
    )

opts.each do |opt, arg|
  case opt
    when '--help'
      usage
      exit 0
    when '--file'
      rulesfile = arg
    when '--gnuplot'
      gnuplot_cmd_file = arg
    when '--output'
      output_data_file = arg
    when '--datafile'
      datafile = arg
    when '--json'
      method = :json
    when '--columns'
      method = :columns
    when '--run'
      run_gnuplot = true
    when '--quiet'
      quiet= true
    when '--imagefile'
      imgfile = arg
    when '--DEBUG'
      debug = true
  end
end

alias debugger nothing unless debug

# read rules from here
if not rulesfile
  usage
  exit 1
end

# read data rows from here
infile = datafile || nil

#
# interesting approach to parsing...?
# >> rxs
# => [/foo$/, /bar\w+/]
# >> x
# => ["foo ", "this foo", "barba", "bar", "bar aba"]
# >> rxs.each { |rx| x.select { |item| if item =~ rx; puts "#{item}, #{rx}"; break; end; } }
#

#
# load the rules 
#
File.open(rulesfile) do |f|
  while ((line = f.gets))
    if line.match(comment_rx)
      next
    elsif ((m = line.match(column_rx)))
      printf("LABEL %s %d\n", m.captures[0], m.captures[1].to_i)
      labels[m.captures[0]] = m.captures[1].to_i
    elsif ((m = line.match(expr_rx))) 
      printf("EXPR %s %s\n", m.captures[0], m.captures[1])
      raw_exprs[m.captures[0]] = m.captures[1]
    elsif ((m = line.match(json_rx))) 
      printf("JSON %s %s\n", m.captures[0], m.captures[1])
      json[m.captures[0]] = m.captures[1]
    elsif ((m = line.match(regexp_define_rx))) 
      printf("REGEXP DEFINED %s %s\n", m.captures[0], m.captures[1])
      regexps_defined[m.captures[0]] = Regexp.new(m.captures[1])
    elsif ((m = line.match(regexp_rx))) 
      printf("REGEXP TAG %s %s %d\n", m.captures[0], m.captures[1], m.captures[2].to_i)
      regexps[m.captures[0]] = [m.captures[1], m.captures[2].to_i]
    elsif ((m = line.match(x_rx))) 
      printf("X AXIS %s %s\n", m.captures[0], m.captures[1]) 
      x_axis[m.captures[0]] = ensure_quoted_string(m.captures[1])
    elsif ((m = line.match(delimiter_rx))) 
      printf("DELIMITER %s\n", m.captures[0])
      column_delimiter = Regexp.new(m.captures[0])
    elsif ((m = line.match(timeseries_rx))) 
      printf("TIMESERIES %s\n", m.captures[0] =~ /true/i)
      timeseries = m.captures[0] =~ /true/i
    elsif ((m = line.match(y_rx))) 
      printf("Y AXIS %s %s\n", m.captures[0], m.captures[1])
      y_axis[m.captures[0]] = ensure_quoted_string(m.captures[1])
    elsif ((m = line.match(y2_rx))) 
      printf("Y2 AXIS %s %s\n", m.captures[0], m.captures[1])
      y2_axis[m.captures[0]] = ensure_quoted_string(m.captures[1])
    elsif ((m = line.match(title_rx))) 
      printf("TITLE %s\n", m.captures[0])
      title = ensure_quoted_string(m.captures[0])
    elsif ((m = line.match(imgfile_rx))) 
      printf("FILE %s\n", m.captures[0])
      imgfile = m.captures[0]
    else
      printf("ERROR: %s \n", line)
    end
  end
end

debugger

#
# basic validation
#

# need an x axis
if x_axis.empty?
  puts "Need an x axis"
  usage
  exit 3
end

# need at least one y axis
if y_axis.empty? and y2_axis.empty?
  puts "Need at least one y axis"
  usage
  exit 3
end


#
# rules postprocessing
#


# make the expressions work via eval
# iterate over elements of each expr:
#   substitute value or json references (foo -> values['foo'])
#
raw_exprs.each do |k,e|
  final = ""
  s = tokenize(e)
  s.each do |clause|
    if labels.has_key? clause or json.has_key? clause
      final << " values['#{clause}']"
    else
      final << " #{clause}"
    end
  end
  puts "final #{k} = #{final}"
  exprs[k] = final
end
      

#
# process the input
#

output = []

if method == :columns
  values = {}

  toplevel_object = infile ? File.open(infile) { |f| f.readlines } : STDIN.readlines
  toplevel_object.each do |line| 
    # for simple cases, assign tags to numeric columns
    cols = line.strip.split(column_delimiter)
    labels.keys.each do |l| 
      i = labels[l]           # the column number
      c = cols[i]             # value at that column
      next if not c
      if c.to_f.to_s == c     # keep numeric types correct
        values[l] = c.to_f
      elsif c.to_i.to_s == c
        values[l] = c.to_i
      elsif looks_like_date(c) 
        values[l] = DateTime.parse(c)
      else
        values[l] = c 
      end
    end

    # for more elaborate cases, assign tags to regexp captures

    # apply each regexp to the input
    rxs = regexps_defined.keys.inject({}) { |r,i| r[i] = line.match(regexps_defined[i]); r }

    # set each labeled value
    regexps.keys.each do |r|
      m = rxs[regexps[r][0]]
      values[r] = m.captures[regexps[r][1]]
    end
    
    result = {}

    # resolve expressions
    exprs.each do |k, e|
      x = eval e rescue "undefined"
      printf("%s -> %s\n", k, x)
      result[k] = x
    end
  
    # done
    puts result.merge(values).inspect unless quiet
    output << result.merge(values)
  end

elsif method == :json

    toplevel_object = infile ? File.open(infile) { |f| JSON.parse(f.readlines.join) } : JSON.parse(STDIN.readlines.join) 
    puts toplevel_object.inspect unless quiet

    # assume toplevel object is an array of entries
    if toplevel_object.class != Array
      puts "Top level must be an Array!"
      exit 2
    end

    # iterate over the entries
    toplevel_object.each do |e|
      values = {}

      # assign tags to elements of the entry
      json.each do |label, expr|
        x = eval(expr)
        puts "json #{label} -> #{x}" unless quiet 
        if looks_like_date(x) 
          values[label] = DateTime.parse(x)
        else
          values[label] = x
        end
      end

      result = {}

      # resolve expressions
      exprs.each do |k, e|
       printf("resolve #{k} -> #{e}\n", k, e)
       x = eval e rescue "unknown"
       printf("%s -> %s\n", k, x)
       result[k] = x
     end

    # done
    puts result.merge(values).inspect unless quiet
    output << result.merge(values)
  end

end 
  
# now output contains a hash for each record to be plotted
  

#
# calculate x-axis params
#

debugger
# which element is x-axis (time) ?
x_elt = x_axis.keys[0]
puts "using x elt #{x_elt}"

# get min/max time value
xvals = output.collect { |e| e[x_elt] }
xvals.sort!
# xmin = DateTime.parse(xvals.first)
# xmax = DateTime.parse(xvals.last)
xmin = xvals.first
xmax = xvals.last
puts "x: #{xmin.to_s} - #{xmax.to_s}"

if timeseries
  # pick a format based on min-max interval
  d = (xmax - xmin).to_i
  if d < 3
    # < 3 days, use hours
    xaxis_format = "%m/%d %H:%M"
  elsif d < 90
    # < 3 months, use days
    xaxis_format = "%m/%d"
  else
    xaxis_format = "%m/%d/%y"
  end
end

# compute min/max range for each y axis (add 5 % buffer?)

# set up column index, title for each y axis
y_axis_data = y_axis.keys.inject([]) { |r,i| r << y_axis[i]; r } if not y_axis.empty?
y2_axis_data = y2_axis.keys.inject([]) { |r,i| r << y2_axis[i]; r } if not y2_axis.empty?

gnuplot_cmd_file = "./gnuplot.cmds" if not gnuplot_cmd_file
output_data_file = "./out" if not output_data_file

File.open(gnuplot_cmd_file, "w") do |f|
  if imgfile
    f.puts "set terminal png size 1024,768"
    f.puts "set output '#{imgfile}'"
    f.puts "set size ratio 0.5"
  end
  f.puts "set title #{title}" if title
  if timeseries
    f.puts "set xdata time"
    f.puts "set timefmt \"%Y-%m-%d+%H:%M:%S\"" 
    f.puts "set format x \"#{xaxis_format}\""
    f.puts "set xrange [\"#{xmin.strftime("%Y-%m-%d+%H:%M:%S")}\":\"#{xmax.strftime("%Y-%m-%d+%H:%M:%S")}\"]"
  end
debugger
  if not y_axis.empty?
    f.puts "set ylabel \"#{y_axis_data.inject([]) {|r,i| r << i.gsub(/'|"/, "") if (i and i.length > 0); r }.join(" / ")}\"" 
  end
  if not y2_axis.empty?
    f.puts "set y2label \"#{y2_axis_data.inject([]) {|r,i| r << i.gsub(/'|"/, "") if (i and i.length > 0); r }.join(" / ")}\"" 
    f.puts "set y2tics"
    f.puts "set ytics nomirror"
  end

  f.puts "plot  \\"

  # y columns start after the x column
  if not y_axis.empty?
    lasty = y_axis_data.length - 1
    y_axis_data.each_index do |y| 
      s = y < lasty ? "," : ""
      f.puts "\"#{output_data_file}\" using 1:#{y + 2} with lines title #{y_axis_data[y]} #{s}  \\"  
    end

    f.puts ",    \\" if y2_axis.length > 0
  end

  # y2 columns are after all the y columns
  if not y2_axis.empty?
    lasty ||= 0
debugger
    lasty2 = y2_axis_data.length - 1 
    y2_axis_data.each_index do |y| 
      s = y < lasty2 ? "," : ""
      f.puts "\"#{output_data_file}\" using 1:#{y + 2 + lasty} axis x1y2 with lines title #{y2_axis_data[y]} #{s}  \\"  
    end
    f.puts
  end
end

# write out gnuplot source data file (date in appropriate format!)

# x_elt is assumed to be date (but this sort should work regardless?)
output.sort! do |e1, e2|
  e1[x_elt] <=> e2[x_elt]
end

debugger
File.open(output_data_file, "w") do |f|
  output.each do |e|
    if timeseries
      s = e[x_elt].strftime("%Y-%m-%d+%H:%M:%S")      # standard time format
    else
      s = e[x_elt].to_s
    end
    y_axis.keys.each do |y|
      s << "\t#{e[y].to_s}"
    end
    y2_axis.keys.each do |y|
      s << "\t#{e[y].to_s}"
    end
    f.puts s
  end 
end

system  "gnuplot #{gnuplot_cmd_file}" if run_gnuplot
