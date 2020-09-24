#!/usr/bin/env crystal

params = {} of String => Array(String)

# params["xprt"] = {}
xprt = {} of String => Array(String)

# params["xprt"]["tcp"] = %w(srcport bind_count connect_count connect_time idle_time
xprt["tcp"] = %w(srcport bind_count connect_count connect_time idle_time
  sends recvs bad_xids req_u bklog_u max_slots sending_u pending_u)

# params["xprt"]["udp"] = %w(srcport bind_count sends recvs bad_xids
xprt["udp"] = %w(srcport bind_count sends recvs bad_xids
  req_u bklog_u max_slots sending_u pending_u)

params["rpcstats"] = %w(ops ntrans timeouts bytes_sent bytes_recv queue rtt execute)

params["bytecounters"] = %w(NFSIOS_NORMALREADBYTES NFSIOS_NORMALWRITTENBYTES NFSIOS_DIRECTREADBYTES
  NFSIOS_DIRECTWRITTENBYTES NFSIOS_SERVERREADBYTES NFSIOS_SERVERWRITTENBYTES
  NFSIOS_READPAGES NFSIOS_WRITEPAGES)

params["fscachecounters"] = %w(NFSIOS_FSCACHE_PAGES_READ_OK NFSIOS_FSCACHE_PAGES_READ_FAIL NFSIOS_FSCACHE_PAGES_WRITTEN_OK
  NFSIOS_FSCACHE_PAGES_WRITTEN_FAIL NFSIOS_FSCACHE_PAGES_UNCACHED)

params["eventcounters"] = %w(NFSIOS_INODEREVALIDATE NFSIOS_DENTRYREVALIDATE NFSIOS_DATAINVALIDATE
  NFSIOS_ATTRINVALIDATE NFSIOS_VFSOPEN NFSIOS_VFSLOOKUP NFSIOS_VFSACCESS
  NFSIOS_VFSUPDATEPAGE NFSIOS_VFSREADPAGE NFSIOS_VFSREADPAGES NFSIOS_VFSWRITEPAGE
  NFSIOS_VFSWRITEPAGES NFSIOS_VFSGETDENTS NFSIOS_VFSSETATTR NFSIOS_VFSFLUSH NFSIOS_VFSFSYNC
  NFSIOS_VFSLOCK NFSIOS_VFSRELEASE NFSIOS_CONGESTIONWAIT NFSIOS_SETATTRTRUNC NFSIOS_EXTENDWRITE
  NFSIOS_SILLYRENAME NFSIOS_SHORTREAD NFSIOS_SHORTWRITE NFSIOS_DELAY NFSIOS_PNFS_READ NFSIOS_PNFS_WRITE)

def print_values(path, line, params, xprt)
  while (line = STDIN.gets)
    break if line.split.size <= 0

    case line
    when /\s*([\w]+):\s*([0-9]+)$/
      puts "#{path}.#{$1}: #{$2}"
    when /\s*([a-zA-Z]+):\s*(udp|tcp)?\s*([\s0-9]+)$/
      print($1, $2, path, $3.split, params, xprt)
    end
  end
end

def check_params(type, values, sub_type, params, xprt)
  case type
  when "events"
    used = params["eventcounters"]
  when "bytes"
    used = params["bytecounters"]
  when "xprt"
    used = xprt[sub_type]
  when "fsc"
    used = params["fscachecounters"]
  else
    return unless values.size == params["rpcstats"].size

    used = params["rpcstats"]
  end
  used
end

def print(type, sub_type, path, values, params, xprt)
  prefix = path + "." + type
  prefix = prefix + "." + sub_type if sub_type
  used = check_params(type, values, sub_type, params, xprt)
  return if !used
  values.each_with_index do |value, i|
    puts "#{prefix}.#{used[i]}: #{value}"
  end
end

while (line = STDIN.gets)
  case line
  when /^time:/
    puts line
  when /^device.+mounted on (.+) with fstype nfs(\s+.+)?$/
    path = $1
    print_values(path, line, params, xprt)
  end
end
