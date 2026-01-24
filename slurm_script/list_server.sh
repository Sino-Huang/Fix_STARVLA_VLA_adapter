echo Pls execute this
echo 'ssh $(squeue | grep sukai | awk '{print $NF}')'