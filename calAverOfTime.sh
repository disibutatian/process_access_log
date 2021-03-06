#!/bin/bash

###  gloable varible  ###
result=(0 0 0)
logLineSum=0
splitLineSum=0

preTreatDir="/tmp/preDir"
pretreatFilename=""
splitDir="/tmp/splitDir"
resultDir="/tmp/resultDir"              ### tmp directory has no authority problem
keyword="/Commercial "

###
function create_dir() {
    if [ -d "$1" ];then                 ### avoid file confilct in the creating directory 
        if [ "$2" = 1 ];then
            timepara=`date "+%s"`
            preTreatDir="$preTreatDir""$timepara"
            mkdir "$preTreatDir"
        elif [ "$2" = 2 ];then
            timepara=`date "+%s"`
            splitDir="$splitDir""$timepara"
            mkdir "$splitDir"
        elif [ "$2" = 3 ];then
            timepara=`date "+%s"`
            resultDir="$resultDir""$timepara"
            mkdir "$resultDir"
        else
            echo "directory type is not provided." 
        fi
    else
        mkdir "$1"
    fi
}

###
function delete_tmp_dir() {
    if [ -d "$1" ];then
        rm -r "$1"
    else
        echo "have no "$1" directory."
    fi
}

###
function preTreat() {
    create_dir $2  1                  ### the second para represent the directory type  
    pretreatFilename="$preTreatDir""/midFile.txt"
    grep "$keyword" "$1" > $pretreatFilename    ### pretreat the acccess.log , acquire the keyword file.
}


###
function calculate_log_line_sum() {
    logLineSum=` cat "$1" | wc -l `
}

###
function calculate_split_line_sum() {
    if [ "$1" -gt 100 ];then 
       splitLineSum=` expr "$1"  / 20 ` 
    else
       splitLineSum="$1"
    fi
}

###
function print_result() {
    #echo "sumOfLine              ""${result[0]}"
    echo "sumOfLine              ""$logLineSum"  ### adapt the pretreatment way 
    echo "sumOfeffectiveLine     ""${result[1]}"
    echo "sumOfTime              ""${result[2]}"

    if [ "${result[1]}" = 0 ];then
        echo "have no effective match line "
    else
        averageResult=` echo "scale=3;  ${result[2]} / ${result[1]} " | bc`
        echo "average result is      "$averageResult
    fi
}

###
function split_log_file() {
    create_dir "$2" 2
    filename=$1
    filename=${filename##*/}            ### acquire the file name of the path 
    cp "$1" "$splitDir"
    cd "$splitDir"

    split -l "$3" -a 4 -d "$filename" 

    rm "$filename"
    cd - > /dev/null
}

###
function summary_result() {
    index=0
    for file in $1                     ### $1 can't add ""("$1"),it will result in parsing $1 failure
    do    
        while read line
        do
        val=$(echo $line | awk '{print $1}')
        result[$index]=` echo " ${result[$index]} + $val " | bc `
        let index+=1
        done < "$file"                    
        index=0
    done
}

###
function process_split_log_context() {
    sumOfLine=0
    sumOfeffectiveLine=0
    sumOfTime=0 
    while read line
    do
        if [ -z "$line" ]; then
            continue;
        fi
        let sumOfLine+=1
        str=$(echo $line | grep "$keyword") 

        if [ -z "$str" ]; then
            continue;
        fi

        let sumOfeffectiveLine+=1
        timeVal=$(echo $str | awk '{print $NF}')
        sumOfTime=` echo "$sumOfTime + $timeVal" | bc `
    done < $1                                               
    
    filename="$2""/""$3"".txt"                                      ### store the temparary result of each back-end process to corresponding file   
    echo "$sumOfLine"  > "$filename"        
    echo "$sumOfeffectiveLine" >> "$filename"
    echo "$sumOfTime" >> "$filename"
}

### 
function traversal_split_dir() {
    create_dir "$2" 3
    dir="$1""/*"
    fileCount=0
    
    for file in $dir   
    do 
        if [ -f "$file" ];then
            process_split_log_context "$file" "$resultDir" "$fileCount" &           ### run at the back-end ,to improve the performence 
            #process_split_log_context "$file" "$2" "$fileCount" &                  ### run at the back-end ,to improve the performence 
            let fileCount+=1
        else
            echo "$file is not a file"
        fi
    done

    wait
    #dir="$2""/*"
    dir="$resultDir""/*"                                                            ### resultDir may be changed by the "  create_dir "$2" 3 "
    summary_result "$dir" 
}
preTreat $1  "$preTreatDir"                                                                          ### pretreat the access.log ,improve execution efficiency.
calculate_log_line_sum "$pretreatFilename"                                           
calculate_split_line_sum "$logLineSum"                                              

calculate_log_line_sum "$1"                                                          ### $1 is the absolute or relative path
#echo "$logLineSum"

split_log_file "$pretreatFilename" "$splitDir" "$splitLineSum"
traversal_split_dir "$splitDir" "$resultDir"

delete_tmp_dir "$splitDir"
delete_tmp_dir "$resultDir"
delete_tmp_dir "$preTreatDir"

print_result
