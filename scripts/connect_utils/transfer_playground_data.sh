# check device name contain fitcluster or darpa

device_name=$(cat /etc/hostname | tr -d '\n')
if [[ "$device_name" != *"fitcluster"* ]]; then
    # then it means we can directly use rsync 
    rsync -chavP sukai@darpa_5090_c1:/home/sukai/Project/STAR_VLA_FIX/Fix_STARVLA_VLA_adapter/playground /data/ccu/sukaih/VLA_FIX_PROJECT/Fix_STARVLA_VLA_adapter/

elif [[ "$device_name" != *"darpa"* ]]; then
    # we can do ssh -p 22549 sukaih@localhost to monash due to ssh tunnel
    # so copy local stuffs from darpa to monash 
    rsync -chavP -e "ssh -p 22549" /home/sukai/Project/STAR_VLA_FIX/Fix_STARVLA_VLA_adapter/playground sukaih@localhost:/data/ccu/sukaih/VLA_FIX_PROJECT/Fix_STARVLA_VLA_adapter/