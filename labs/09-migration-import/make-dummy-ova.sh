#!/usr/bin/env bash
# Best-effort helper: wrap a qcow2 into a minimal .ova so you can practise the import.
# Usage: ./make-dummy-ova.sh <disk.qcow2> <name>     (needs qemu-img, python3, tar)
# A real VMware/VirtualBox export is a better test; this OVF may need tweaks for MTV.
set -euo pipefail
src=${1:?qcow2 file}; name=${2:?vm name}
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
qemu-img convert -f qcow2 -O vmdk -o subformat=streamOptimized "$src" "$work/$name-disk1.vmdk"
cap=$(qemu-img info --output json "$src" | python3 -c 'import sys,json;print(json.load(sys.stdin)["virtual-size"])')
cat > "$work/$name.ovf" <<OVF
<?xml version="1.0" encoding="UTF-8"?>
<Envelope xmlns="http://schemas.dmtf.org/ovf/envelope/1" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData">
  <References><File ovf:id="file1" ovf:href="$name-disk1.vmdk"/></References>
  <DiskSection><Info>Virtual disks</Info>
    <Disk ovf:diskId="vmdisk1" ovf:fileRef="file1" ovf:capacity="$cap" ovf:capacityAllocationUnits="byte" ovf:format="http://www.vmware.com/interfaces/specifications/vmdk.html#streamOptimized"/>
  </DiskSection>
  <NetworkSection><Info>Networks</Info><Network ovf:name="VM Network"><Description>VM Network</Description></Network></NetworkSection>
  <VirtualSystem ovf:id="$name"><Info>$name</Info><Name>$name</Name>
    <OperatingSystemSection ovf:id="96"><Info>Linux</Info></OperatingSystemSection>
    <VirtualHardwareSection><Info>Hardware</Info>
      <System><vssd:ElementName>Virtual Hardware Family</vssd:ElementName><vssd:InstanceID>0</vssd:InstanceID><vssd:VirtualSystemType>vmx-13</vssd:VirtualSystemType></System>
      <Item><rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits><rasd:ElementName>2 virtual CPU</rasd:ElementName><rasd:InstanceID>1</rasd:InstanceID><rasd:ResourceType>3</rasd:ResourceType><rasd:VirtualQuantity>2</rasd:VirtualQuantity></Item>
      <Item><rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits><rasd:ElementName>4096MB of memory</rasd:ElementName><rasd:InstanceID>2</rasd:InstanceID><rasd:ResourceType>4</rasd:ResourceType><rasd:VirtualQuantity>4096</rasd:VirtualQuantity></Item>
      <Item><rasd:Address>0</rasd:Address><rasd:ElementName>SCSI Controller</rasd:ElementName><rasd:InstanceID>3</rasd:InstanceID><rasd:ResourceSubType>lsilogic</rasd:ResourceSubType><rasd:ResourceType>6</rasd:ResourceType></Item>
      <Item><rasd:AddressOnParent>0</rasd:AddressOnParent><rasd:ElementName>Hard Disk 1</rasd:ElementName><rasd:HostResource>ovf:/disk/vmdisk1</rasd:HostResource><rasd:InstanceID>4</rasd:InstanceID><rasd:Parent>3</rasd:Parent><rasd:ResourceType>17</rasd:ResourceType></Item>
      <Item><rasd:AutomaticAllocation>true</rasd:AutomaticAllocation><rasd:Connection>VM Network</rasd:Connection><rasd:ElementName>Ethernet 1</rasd:ElementName><rasd:InstanceID>5</rasd:InstanceID><rasd:ResourceSubType>E1000</rasd:ResourceSubType><rasd:ResourceType>10</rasd:ResourceType></Item>
    </VirtualHardwareSection>
  </VirtualSystem>
</Envelope>
OVF
tar -C "$work" -cf "$name.ova" "$name.ovf" "$name-disk1.vmdk"
echo "Created $name.ova"
