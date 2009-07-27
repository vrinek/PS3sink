def debug(this, indent = 0, from_hash = false)
  if this.is_a?(Array)
    (from_hash ? '' : "\t"*indent) + "[\n" + this.collect{|i|
      debug(i, indent + 1)
    }.join(",\n")+"\n" + "\t"*indent + "]"
    
  elsif this.is_a?(Hash)
    (from_hash ? '' : "\t"*indent) + "{\n" + this.keys.collect{|k|
      "\t"*(indent + 1) + debug(k) + ' => ' + debug(this[k], indent + 1, true)
    }.join(",\n")+"\n" + "\t"*indent + "}"
    
  else
    (from_hash ? '' : "\t"*indent) + this.inspect
  end
end