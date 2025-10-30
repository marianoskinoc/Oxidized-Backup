class TPLink < Oxidized::Model
  using Refinements

  # tp-link prompt
  prompt /^\r?([\w.@()-]+[#>]\s?)$/
  comment '! '

  # handle paging
  # workaround for sometimes missing whitespaces with "\s?"
  expect /Press\s?any\s?key\s?to\s?continue\s?\(Q\s?to\s?quit\)/ do |data, re|
    send ' '
    data.sub re, ''
  end

  # send carriage return because \n with the command is not enough
  # checks if line ends with prompt >,# or \r,\nm otherwise send \r
  expect /[^>#\r\n]$/ do |data, re|
    send "\r"
    data.sub re, ''
  end

  cmd :all do |cfg|
    # remove unwanted paging line
    cfg.gsub! /^Press any key to contin.*/, ''
    # normalize linefeeds
    cfg.gsub! /(\r|\r\n|\n\r)/, "\n"
    # remove empty lines
    cfg.each_line.reject { |line| line.match /^[\r\n\s\u0000#]+$/ }.join
  end

  cmd :secret do |cfg|
    cfg.gsub! /^enable password (\S+)/, 'enable password <secret hidden>'
    cfg.gsub! /^user (\S+) password (\S+) (.*)/, 'user \1 password <secret hidden> \3'
    cfg.gsub! /^(snmp-server community).*/, '\\1 <configuration removed>'
    cfg.gsub! /secret (\d+) (\S+).*/, '<secret hidden>'
    cfg
  end

  cmd 'show system-info' do |cfg|
    cfg.gsub! /(System Time\s+-).*/, '\\1 <stripped>'
    cfg.gsub! /(Running Time\s+-).*/, '\\1 <stripped>'
    comment cfg.each_line.to_a[3..-3].join
  end

  cmd 'show running-config' do |cfg|
    # Some TP-Link variants may not support 'show running-config'.
    # If the device returns an error, try a few alternative commands
    # to obtain the running configuration.
    if cfg =~ /Bad command|Error:/i
      alt_cmds = [
        'show running-config', # try original again
        'show configuration',
        'show config',
        'display current-configuration',
        'show startup-config'
      ]
      alt_output = nil
      alt_cmds.each do |c|
        begin
          # Use the input to execute alternative command
          alt = @input.cmd(c)
        rescue StandardError
          alt = nil
        end
        next unless alt
        # skip outputs that still contain errors
        next if alt =~ /Bad command|Error:/i
        alt_output = alt
        break
      end
      cfg = alt_output if alt_output
    end

    lines = cfg.each_line.to_a[1..-1]
    # cut config after "end" (if present)
    if lines && lines.index("end\n")
      lines[0..lines.index("end\n")].join
    else
      # fallback: return everything except the first line
      (lines || []).join
    end
  end

  cfg :ssh do
    username /^User ?[nN]ame:/
    password /^\r?Password:/
  end

  cfg :ssh do
    post_login do
      if vars(:enable) == true
        cmd "enable"
      elsif vars(:enable)
        cmd "enable", /^[pP]assword:/
        cmd vars(:enable)
      end
    end

    pre_logout do
      send "exit\r"
      send "logout\r"
    end
  end
end
