cat <<EOF > draw.sh
#!/bin/bash
#CP4D dependancy graph
#Linux version

echo Make sure you are in the correct namespace \(oc project X\)

#Preparation (one time):
#download jq, if already there, please change ./jq in the Execution section to jq
FILE=./jq
if [ -f "\$FILE" ]; then
    echo "\$FILE already downloaded"
else
    wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
    chmod +x ./jq
fi

#extract the data from the CPD operator - make sure that you are in the correct project
oc get  cpdinstall cr-cpdinstall -o json >test.json;

echo if you want to look at the pods as well, set the pod_module variable by passing the name as an argument \(for example 0010-infra\)
echo if you set this to all , the graph gets very large
if [ -z "\$1" ]
    then pod_module="none"
else
    pod_module=\$1
fi
echo pod_module=\$pod_module

#Execution:
#styling and initial module loop
echo digraph CP4D { > output.txt ;
echo node \[fontsize = 36,style = filled,color=salmon2] >> output.txt; 
echo layout=fdp K=0.5 overlap=scale splines=polyline\; >> output.txt;
for module in \$(./jq '.spec.modules|map(.name)|join(" ")' test.json| sed 's/"//g'); 
    do 
        #change styling for modules
        echo \"\$module\" \[style = \"\", fontsize = 20, style = filled, color=green] >> output.txt
        for assembly in \$(./jq  --arg v \$module '.spec.modules[]|select(.name == \$v)|.parentAssembly|map(.assembly)|join(" ")' test.json| sed 's/"//g');
            #assembly to module relation
            do echo \"\$assembly\"\-\>\"\$module\" >> output.txt ;
            #handle cases where modules have the same names as assemblies (wml for example)
            if [ \$module == \$assembly ]
                then echo \"\$module\" \[fontsize = 36,style = filled,color=salmon2] >> output.txt;
            fi
        done;
        #add pod -> module relation 
        if [ \$module == \$pod_module ] || [ \$pod_module == 'all' ]                     
            then for pod in \$(oc get po -l release=\$module -o custom-columns=:metadata.name --no-headers);                
                do echo \"\$pod\" \[style = \"\", fontsize = 10, style = filled, color=grey] >> output.txt; 
                echo \"\$pod\"\-\>\"\$module\" >> output.txt;
            done;
        fi
    done; 
echo \} >> output.txt;
echo Results in output.txt;
echo Copy contents of the output.txt, visit http://viz-js.com/, paste the content and enjoy!.    
EOF
chmod +x draw.sh
./draw.sh
