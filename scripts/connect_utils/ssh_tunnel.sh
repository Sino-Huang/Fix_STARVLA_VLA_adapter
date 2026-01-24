# tunnel between monash nlp and darpa server

# check the device name contain fitcluster or spartan 
device_name=$(cat /etc/hostname | tr -d '\n')
if [[ "$device_name" != *"fitcluster"* && "$device_name" != *"spartan"* ]]; then
    echo "This script is only for monash nlp cluster (fitcluster) to darpa server (darpa). Current device: ${device_name}"
    exit 1  
fi

# start tmux session for ssh tunnel
sessname="ssh_tunnel_to_darpa"
tmux new-session -d -s "$sessname"
if [[ $? -eq 1 ]]; then
    tmux kill-session -t "$sessname"
    echo "Killed existing tmux session: $sessname"
    sleep 3
    echo "Starting new tmux session: $sessname"
    tmux new-session -d -s "$sessname"
fi

pane_to_darpa="$sessname:0.0"
tmux select-pane -t "$pane_to_darpa" -T "to-darpa-server"
# connect to darpa server
echo "Connecting to Darpa Server..."

tmux send-keys -t "$pane_to_darpa" "ssh -N -R 22549:localhost:22 sukai@darpa_5090_c1" Enter
sleep 1


# create a tmux pane to save the instruction 
tmux split-window -h -t "$pane_to_darpa"
pane_instructions=$(tmux display-message -p '#{pane_id}')
tmux select-pane -t "$pane_instructions" -T "instructions"
tmux send-keys -t "$pane_instructions" "echo 'On Darpa Server, run: ssh -p 22549 sukaih@localhost'" Enter
echo "On Darpa Server, run: ssh -p 22549 sukaih@localhost"
# give instruction to use rsync to transfer files
tmux send-keys -t "$pane_instructions" "echo 'To transfer files from Monash to Darpa, run: rsync -avz -e \"ssh -p 22549\" /path/to/local/ sukaih@localhost:/path/to/remote/'" Enter
echo "To transfer files from Monash to Darpa, run: rsync -avz -e \"ssh -p 22549\" /path/to/local/ sukaih@localhost:/path/to/remote/"
tmux send-keys -t "$pane_instructions" "echo 'To transfer files from Darpa to Monash, run: rsync -avz -e \"ssh -p 22549\" sukaih@localhost:/path/to/remote/ /path/to/local/'" Enter
echo "To transfer files from Darpa to Monash, run: rsync -avz -e \"ssh -p 22549\" sukaih@localhost:/path/to/remote/ /path/to/local/"