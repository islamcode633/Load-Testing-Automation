#!/bin/bash

PATH_TO_TEST_OBJ=$(dirname ~/script.sh)/$(basename ~/script.sh)
COMM="sudo bash $PATH_TO_TEST_OBJ"
STEP=0
read -p "Enter first symbol cases p(positive)/n(negative)/l(sysbench): "


function expected_result_of_negative_cases {
    step_case=$1
    case $step_case in
        1|2|3|4|5|6|7|8| \
        9|10|11|12|13|14| \
        15|16|17|18 ) echo Script mode not selected !
        ;;
    esac
}

# Parametrization test:
function positive_case {
    echo -e "\n[\e[32mSTART:\e[0m ] POSITIVE CASE:\n"
    for positive_param in "-u" "-l" "-f" "-d" \
                            "-u -l -f" \
                            "-d -l -f" \
                            "-u -l" \
                            "-u -f" \
                            "-u -d -l" \
                            "-h" "-v"
    do
        sleep 5
        $COMM $positive_param
    done
}

function negative_case {
    echo -e "\n[\e[31mSTART\e[0m] NEGATIVE CASE\n"
    for negative_param in "--l ----f d-d" \
                          "l u" "f" "d" "u l f d" \
                            "123-u8 -f123" \
                            "-u~ ?-d? -l@" \
                            "--u --f --d --l" \
                            "-uuu" "-fff" "-u-u" \
                            "-u--update -f--fmt -d--default" \
                            "" " " "           " \
                             "-ulf" "-fdu" "$\!@#43232$%^&()"
    do
        ((STEP++))
        result=$(expected_result_of_negative_cases $STEP)
        printf "[ \e[32mIn Processing\e[0m ] %s\n" \
                "Step: $STEP Param: $negative_param Expected result: $result"
        sleep 5
        $COMM $negative_param
    done
}

# Wrapp_Sysbench test:
function test_sysbench {
    echo -e " BEGIN CPU BLOCK ! \n"
    $COMM sysbench cpu --threads=48 --cpu-max-prime=10000 --time=90
    echo -e " BEGIN MEMORY BLOCK ! \n"
    $COMM sysbench memory --memory-block-size=512K  --memory-total-size=1024G \
                            --memory-operation=none --time=360
    echo -e " BEGIN FILEIO BLOCK ! \n"
    $COMM sysbench fileio --file-num=10 --file-total-size=20G \
						--file-test-mode=seqwr --time=180 run
}

if [[ $REPLY == p ]]; then
   positive_case
elif [[ $REPLY == n ]]; then
   negative_case
elif [[ $REPLY == l ]]; then
   test_sysbench
fi
