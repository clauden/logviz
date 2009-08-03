#
# given a set of columns, assign tag to each
#
require 'rubygems'; require 'ruby-debug'
require 'getoptlong'
require 'json'



labels = {}
raw_exprs = {}
exprs = {}
json = {}
regexps = {}
rulesfile = nil

def usage
  puts "--file <rulesfile>"
end


def tokenize(s)
  result = []
  w = ""
  i = 0
  last = nil
  s.split(//).each do |c|
    puts "#{c} : #{last} : #{w}"
    if c =~ /\w/ 
      if last == :word or not last
        w << c
        last = :word
      else
        result << w.strip
        last = :word
        w = "#{c}"
      end
    else 
      if last == :word or not last
        result << w.strip
        last = :notword
        w = "#{c}"
      else
        w << c
        last = :notword
      end
    end
  end
  result << w.strip
  result
end 


# "LABEL some-tag COLUMN some-column"
# column_rx = /\W*label\W+(\w+)\W+column\W+(\d+)/i
column_rx = /\s*label\s+(\w+)\s+column\s+(\d+)/i

# "LABEL some-tag EXPR some-expr"
# expr_rx = /\W*label\W+(\w+)\W+expr\W+(.+)/i
expr_rx = /\s*label\s+(\w+)\s+expr\s+(.+)/i

# "LABEL some-tag JSON json-expr"
json_rx = /\s*label\s+(\w+)\s+json\s+(.+)/i

# "REGEXP some-tag some-regexp"
# regexp_rx = /\W*regexp\W+(\w+)\W+(.+)/i 
regexp_rx = /\s*regexp\s+(\w+)\s+(.+)/i 


#
# main begins
#

opts = GetoptLong.new(
      [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
      [ '--file', '-f', GetoptLong::REQUIRED_ARGUMENT ]
    )

opts.each do |opt, arg|
  case opt
    when '--help'
      usage
    when '--file'
      rulesfile = arg
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
    end
  end
end

#
# rules postprocessing
#

# make the expressions work via eval
# iterate over elements of each expr:
#   substitute value references (foo -> values['foo'])
#
raw_exprs.each do |k,e|
  final = ""
  s = tokenize(e)
  s.each do |clause|
    if labels.has_key? clause
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
    x = eval e
    printf("%s -> %s\n", k, x)
    result[k] = x
  end
  
  # done
  puts result.merge(values).inspect
end 
  
  
