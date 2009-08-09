#
# given a set of columns, assign tag to each
#
require 'rubygems'; require 'ruby-debug'
require 'getoptlong'
require 'json'
require 'tokenize'

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
regexps = {}
rulesfile = nil

x_axis = {}
y_axis = {}

datafile = nil
debug = nil

#
# data extraction directives
#

# # anything
comment_rx = /\s*\#/

# "DELIMITER some-regex-or-character"
delimiter_rx = /\s*DELIMITER\s+(.*)/i

# "LABEL some-tag COLUMN some-column"
column_rx = /\s*LABEL\s+(\w+)\s+COLUMN\s+(\d+)/i

# "LABEL some-tag EXPR some-expr"
expr_rx = /\s*LABEL\s+(\w+)\s+EXPR\s+(.+)/i

# "LABEL some-tag JSON json-expr"
json_rx = /\s*LABEL\s+(\w+)\s+JSON\s+(.+)/i

# "REGEXP some-tag some-regexp"
regexp_rx = /\s*REGEXP\s+(\w+)\s+(.+)/i 

# "TIMESERIES true-or-false" 
timeseries_rx = /\s*TIMESERIES\s+(\w+)/i 


#
# gnuplot directives
#

# "XAXIS some-tag label 
x_rx = /\s*xaxis\s+(\w+)\s+(.*)/

# "YAXIS some-tag label
y_rx = /\s*yaxis\s+(\w+)\s+(.*)/


def looks_like_date(x)
  rv = nil
  begin
    rv = DateTime.parse(x)
  rescue
    nil
  end
  rv
end

#
# main begins
#

def usage
  puts "--file <rulesfile> [--columns | --json]"
end

opts = GetoptLong.new(
      [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
      [ '--file', '-f', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--columns', '-c', GetoptLong::NO_ARGUMENT ],
      [ '--json', '-j', GetoptLong::NO_ARGUMENT ],
      [ '--datafile', '-d', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--DEBUG', '-D', GetoptLong::NO_ARGUMENT ]
    )

opts.each do |opt, arg|
  case opt
    when '--help'
      usage
    when '--file'
      rulesfile = arg
    when '--datafile'
      datafile = arg
    when '--json'
      method = :json
    when '--columns'
      method = :columns
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
      debugger
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
    elsif ((m = line.match(regexp_rx))) 
      printf("REGEXP %s %s\n", m.captures[0], m.captures[1])
      regexps[m.captures[0]] = Regexp.new(m.captures[1])
    elsif ((m = line.match(x_rx))) 
      printf("X AXIS %s %s\n", m.captures[0], m.captures[1]) 
      x_axis[m.captures[0]] = m.captures[1]
    elsif ((m = line.match(delimiter_rx))) 
      printf("DELIMITER %s\n", m.captures[0])
      column_delimiter = Regexp.new(m.captures[0])
    elsif ((m = line.match(timeseries_rx))) 
      printf("TIMESERIES %s\n", m.captures[0] =~ /true/i)
      timeseries = m.captures[0] =~ /true/i
    elsif ((m = line.match(y_rx))) 
      printf("Y AXIS %s %s\n", m.captures[0], m.captures[1])
      y_axis[m.captures[0]] = m.captures[1]
    end
  end
end


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
if y_axis.empty?
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
    cols = line.split(column_delimiter)
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
    
    
    result = {}

    # resolve expressions
    exprs.each do |k, e|
      x = eval e rescue "undefined"
      printf("%s -> %s\n", k, x)
      result[k] = x
    end
  
    # done
    puts result.merge(values).inspect
    output << result.merge(values)
  end

elsif method == :json

    toplevel_object = infile ? File.open(infile) { |f| JSON.parse(f.readlines.join) } : JSON.parse(STDIN.readlines.join) 
    puts toplevel_object.inspect

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
        puts "json #{label} -> #{x}"
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
    puts result.merge(values).inspect
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
    xaxis_format = "%m/%d/%Y"
  end
end

# compute min/max range for each y axis (add 5 % buffer?)

# set up column index, title for each y axis
y_axis_data = y_axis.keys.inject([]) { |r,i| r << y_axis[i]; r }

gnuplot_cmd_file = "./gnuplot.cmds"
File.open(gnuplot_cmd_file, "w") do |f|
  if timeseries
    f.puts "set xdata time"
    f.puts "set timefmt \"%Y-%m-%d+%H:%M:%S\"" 
    f.puts "set format x \"#{xaxis_format}\""
    f.puts "set xrange [\"#{xmin.strftime("%Y-%m-%d+%H:%M:%S")}\":\"#{xmax.strftime("%Y-%m-%d+%H:%M:%S")}\"]"
  end
  f.puts "plot  \\"
  lasty = y_axis_data.length - 1
  y_axis_data.each_index do |y| 
    s = y < lasty ? "," : ""
    f.puts "\"out\" using 1:#{y + 2} with lines title #{y_axis_data[y]} #{s}  \\"  
  end
  f.puts
end

# write out gnuplot source data file (date in appropriate format!)

# x_elt is assumed to be date (but this sort should work regardless?)
output.sort! do |e1, e2|
  e1[x_elt] <=> e2[x_elt]
end

debugger
output_data_file = "./out"
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
    f.puts s
  end 
end


