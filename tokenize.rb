module Tokenize
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
end
