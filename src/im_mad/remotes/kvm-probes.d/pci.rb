#!/usr/bin/env ruby

# -------------------------------------------------------------------------- #
# Copyright 2002-2018, OpenNebula Project, OpenNebula Systems                #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

require 'shellwords'
require 'yaml'

begin
    NAME = File.join(File.dirname(__FILE__), '../../etc/im/kvm-probes.d/pci.conf')
    CONF = {
        :filter        => '0:0',
        :short_address => [],
        :device_name   => [],
    }.merge(YAML.load_file(NAME))
rescue
    STDERR.puts "Invalid configuration #{NAME}"
    exit(-1)
end

def get_pci(filter=nil)
    command = "lspci -mmnn"
    command << " -d #{filter}" if filter

    text = %x(#{command})

    text.split("\n").map {|l| Shellwords.split(l) }
end

def get_name_and_id(text)
    m = text.match(/^(.*) \[(....)\]$/)
    return m[1], m[2]
end

def parse_pci(pci)
    card = {}

    card[:short_address] = pci[0]
    card[:libvirt_address] =
        "pci_0000_#{card[:short_address].gsub(/[:.]/, '_')}"
    card[:address] = "0000:#{card[:short_address].gsub(/[:.]/, ':')}"

    card[:class_name], card[:class] = get_name_and_id(pci[1])
    card[:vendor_name], card[:vendor] = get_name_and_id(pci[2])
    card[:device_name], card[:device] = get_name_and_id(pci[3])

    card[:bus], card[:slot], card[:function] = pci[0].split(/[:.]/)

    card[:type] = [card[:vendor], card[:device], card[:class]].join(':')

    card
end

def get_devices(filter=nil)
    if filter
        filter = [filter].flatten.map { |f| f.split(',') }.flatten
    else
        filter = [nil]
    end

    filter.map do |f|
        get_pci(f).map {|pci| parse_pci(pci) }
    end.flatten
end

filter = CONF[:filter]

devices = get_devices(filter)

def pval(name, value)
    %Q(  #{name} = "#{value}")
end

# vendor / device => incr value per different bus
rename = {
  '15b3' => { # Mellanox
    '1014' => '1000', # connectx4 VF
  }
}

count = {}

devices.each do |dev|
    next if !CONF[:short_address].empty? && !CONF[:short_address].include?(dev[:short_address])

    if !CONF[:device_name].empty?
        matched = CONF[:device_name].each { |pattern|
            break true if !(dev[:device_name] =~ /#{pattern}/i).nil?
        }

        next if matched != true
    end

    type = dev[:type]
    device = dev[:device]
    vendor = dev[:vendor]
    if rename.key?(vendor) and rename[vendor].key?(device)
      if not count.key?(vendor)
        count[vendor] = {}
      end
      if not count[vendor].key?(device)
        count[vendor][device] = {}
      end

      # keep track of devices per bus
      bus = dev[:bus]
      if count[vendor][device].key?(bus)
        device = count[vendor][device][bus]
      else
        deviceint = device.hex + rename[vendor][device].hex * count[vendor][device].length
        newdevice = "%04x" % deviceint
        count[vendor][device][bus] = newdevice
        device = newdevice
      end
      type = [dev[:vendor], device, dev[:class]].join(':')
    end

    puts "PCI = ["
    values = [
        pval('TYPE', type),
        pval('VENDOR', dev[:vendor]),
        pval('VENDOR_NAME', dev[:vendor_name]),
        pval('DEVICE', device),
        pval('DEVICE_NAME', dev[:device_name]),
        pval('CLASS', dev[:class]),
        pval('CLASS_NAME', dev[:class_name]),
        pval('ADDRESS', dev[:address]),
        pval('SHORT_ADDRESS', dev[:short_address]),
        pval('DOMAIN', '0000'),
        pval('BUS', dev[:bus]),
        pval('SLOT', dev[:slot]),
        pval('FUNCTION', dev[:function])
    ]

    puts values.join(",\n")
    puts "]"
end

