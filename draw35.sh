#!/bin/bash
#CP4D dependancy graph
#Linux version
echo Make sure you are in the correct namespace \(oc project X\)
#Preparation (one time):
#download jq, if already there, please change ./jq in the Execution section to jq
FILE=./yq
VERSION=3.4.1
BINARY=yq_linux_amd64
if [ -f "$FILE" ]; then
    echo "$FILE already downloaded"
else
    wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
    wget -O yq https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}
    chmod +x ./yq
    chmod +x ./jq
fi

#extract the data from the CPD operator - make sure that you are in the correct project
#oc get  cpdinstall cr-cpdinstall -o json >test.json;
oc get cm cpd-install-spec -o jsonpath='{.data.content}' | base64 -d > test.yaml

echo if you want to look at the pods as well, set the pod_module variable by passing the name as an argument \(for example 0010-infra\)
echo if you set this to all , the graph gets very large
if [ -z "$1" ]
    then pod_module="none"
else
    pod_module=$1
fi
echo pod_module=$pod_module

#Conversion
./yq r test.yaml -j > test.json

#Execution:
#styling and initial module loop
echo digraph CP4D { > output.txt ;
echo node \[fontsize = 36,style = filled,color=salmon2] >> output.txt;
echo layout=fdp K=0.5 overlap=scale splines=polyline\; >> output.txt;
for module in $(./jq '.modules|map(.releaseName)|join(" ")' test.json| sed 's/"//g');
    do
        #change styling for modules
        echo \"$module\" \[style = \"\", fontsize = 20, style = filled, color=green] >> output.txt
        for assembly in $(./jq  --arg v $module '.modules[]|select(.releaseName == $v)|.parentAssembly.name' test.json| sed 's/"//g');
            #assembly to module relation
            do echo \"$module\"\-\>\"$assembly\" >> output.txt ;
            #handle cases where modules have the same names as assemblies (wml for example)
            if [ $module == $assembly ]
                then echo \"$module\" \[fontsize = 36,style = filled,color=salmon2] >> output.txt;
            fi
            #assembly references
            for ref in $(./jq --arg v $assembly '.assemblies[]|select(.id.name == $v)|.referencedBy[].name' test.json -r|tr '\n' ' ');
                do echo \"$ref\"\-\>\"$assembly\" \[arrowhead=\"diamond\",arrowsize=2] >> output.txt ;
            done;
        done;
        #add pod -> module relation
        if [ $module == $pod_module ] || [ $pod_module == 'all' ]
            then for pod in $(oc get po -l release=$module -o custom-columns=:metadata.name --no-headers);
                do echo \"$pod\" \[style = \"\", fontsize = 10, style = filled, color=grey] >> output.txt;
                echo \"$pod\"\-\>\"$module\" >> output.txt;
            done;
        fi
    done;
echo \} >> output.txt;
echo Results in output.txt;
echo Copy contents of the output.txt, visit http://viz-js.com/, paste the content and enjoy!.