#
# given a set of columns, assign tag to each
#
require 'rubygems'; require 'ruby-debug'
require 'getoptlong'
require 'json'
require 'tokenize'

include Tokenize
include Math        # convenience for expressions...

method = :lines

labels = {}
raw_exprs = {}
exprs = {}
json = {}
regexps = {}
rulesfile = nil

x_axis = {}
y_axis = {}


#
# data extraction directives
#

# "LABEL some-tag COLUMN some-column"
column_rx = /\s*label\s+(\w+)\s+column\s+(\d+)/i

# "LABEL some-tag EXPR some-expr"
expr_rx = /\s*label\s+(\w+)\s+expr\s+(.+)/i

# "LABEL some-tag JSON json-expr"
json_rx = /\s*label\s+(\w+)\s+json\s+(.+)/i

# "REGEXP some-tag some-regexp"
regexp_rx = /\s*regexp\s+(\w+)\s+(.+)/i 


#
# gnuplot directives
#

# "XAXIS some-tag label 
x_rx = /\s*xaxis\s+(.*)\s+(.*)/

# "YAXIS some-tag label
y_rx = /\s*yaxis\s+(.*)\s+(.*)/



def usage
  puts "--file <rulesfile> [--columns | --json]"
end



#
# main begins
#

opts = GetoptLong.new(
      [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
      [ '--file', '-f', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--columns', '-c', GetoptLong::NO_ARGUMENT ],
      [ '--json', '-j', GetoptLong::NO_ARGUMENT ]
    )

opts.each do |opt, arg|
  case opt
    when '--help'
      usage
    when '--file'
      rulesfile = arg
    when '--json'
      method = :json
    when '--columns'
      method = :columns
  end
end

if not rulesfile
  usage
  exit 1
end


#
# load the rules 
#
File.open(rulesfile) do |f|
  while ((line = f.gets))
    if ((m = line.match(column_rx)))
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
    elsif ((m = line.match(y_rx))) 
      printf("Y AXIS %s %s\n", m.captures[0], m.captures[1])
      y_axis[m.captures[0]] = m.captures[1]
    end
  end
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
  while((line = STDIN.gets))

    values = {}

    # assign tags to numeric columns
    s = line.split
    labels.keys.each do |l|
      i = labels[l]                   # the column number
      if s[i]
        if s[i].to_f.to_s == s[i]     # keep numeric types correct
          values[l] = s[i].to_f
        elsif s[i].to_i.to_s == s[i]
          values[l] = s[i].to_i
        else
          values[l] = s[i] if s[i]    # use the value if column exists
        end
      end
    end

    result = {}

    # resolve expressions
    debugger
    exprs.each do |k, e|
      x = eval e rescue "undefined"
      printf("%s -> %s\n", k, x)
      result[k] = x
    end
    
    # done
    puts result.merge(values).inspect
    output << result.merge(values).inspect
  end

elsif method == :json

    toplevel_object = JSON.parse(STDIN.readlines.join)
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
        values[label] = x
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
    output << result.merge(values).inspect
  end

end 
  
# now output contains a hash for each record to be plotted
  
# gnuplot preamble

# x axis description (assume time for now)
gnuplot "set xdata time"
puts "x_axis"
# y axes
y_axes.each_key do |k|
end
