require 'pathname'
require 'bigdecimal'


# Cribbed from Unicorn Worker Killer, thanks!
class GetProcessMem
  KB_TO_BYTE = 1024          # 2**10   = 1024
  MB_TO_BYTE = 1_048_576     # 1024**2 = 1_048_576
  GB_TO_BYTE = 1_073_741_824 # 1024**3 = 1_073_741_824
  CONVERSION = { "kb" => KB_TO_BYTE, "mb" => MB_TO_BYTE, "gb" => GB_TO_BYTE }
  ROUND_UP   = BigDecimal.new("0.5")
  attr_reader :pid
  attr_accessor :mem_type

  def initialize(pid = Process.pid, mem_type = nil)
    @process_file = Pathname.new "/proc/#{pid}/smaps"
    @pid          = pid
    @linux        = @process_file.exist?
    @mem_type     = mem_type
  end

  def linux?
    @linux
  end

  def bytes
    memory =   linux_memory if linux?
    memory ||= ps_memory
  end

  def kb(b = bytes)
    (b/BigDecimal.new(KB_TO_BYTE)).to_f
  end

  def mb(b = bytes)
    (b/BigDecimal.new(MB_TO_BYTE)).to_f
  end

  def gb(b = bytes)
    (b/BigDecimal.new(GB_TO_BYTE)).to_f
  end

  def inspect
    b = bytes
    "#<#{self.class}:0x%08x @mb=#{ mb b } @gb=#{ gb b } @kb=#{ kb b } @bytes=#{b}>" % (object_id * 2)
  end

  # linux stores memory info in a file "/proc/#{pid}/smaps"
  # If it's available it uses less resources than shelling out to ps
  # It also allows us to use Pss (the process' proportional share of
  # the mapping that is resident in RAM) as mem_type
  def linux_memory(file = @process_file)
    lines = file.each_line.select {|line| line.match /^#{mem_type || 'Pss'}/ }
    return if lines.empty?
    lines.reduce(0) do |sum, line|
      line.match(/(?<value>(\d*\.{0,1}\d+))\s+(?<unit>\w\w)/) do |m|
        value = BigDecimal.new(m[:value]) + ROUND_UP
        unit  = m[:unit].downcase
        sum += CONVERSION[unit] * value
      end
      sum
    end
  end

  private

  # Pull memory from `ps` command, takes more resources and can freeze
  # in low memory situations
  def ps_memory
    KB_TO_BYTE * BigDecimal.new(`ps -o rss= -p #{pid}`)
  end
end

GetProcessMem
