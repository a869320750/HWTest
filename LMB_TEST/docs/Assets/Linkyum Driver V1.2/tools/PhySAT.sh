#! /bin/bash

# 测试报告统计通过、失败用例数量
function PhyTestResaultStatis(){

    if [ "${gTestResault}" == "pass" ]
    then
        let gPass+=1
    elif [ "${gTestResault}" == "fail" ]
    then
        let gFail+=1
    fi
    let gTotal+=1

}

# 输出用例结果,并对结果进行格式化排版
function PhyTestResultPrintf(){

    printf "%-20s %-20s %20s\n" ${testCaseId} ${gTestResault} ${testCaseTitle} >> ${gReportPath} && cat ${gReportPath}| tail -1

}

# AssertNoIn ${1}不在${2}中则为true
function AssertNoIn(){

    findResult=`echo "${2}"|grep -e "${1}"`
    echo "${findResult}"
    if [ "${findResult}" ]
    then
        gTestResault="pass"
    else
        gTestResault="fail"
        gFailId[${gFail}]=${testCaseId}
    fi
    PhyTestResaultStatis
    PhyTestResultPrintf
}

# 测试Phy第一条用例
function PhyLinkSpeedTestCase1(){
    testCaseId=01                           # 用例编号
    testCaseTitle="phy10Miperf3test"                    # 用例标题
    phyTestResault="connected"             # 用例执行命令结果
    phy_link_10M=`ethtool -s ${1} speed 10 duplex full autoneg on`
    sleep 3
    phy_test_iperf3_10M=`iperf3 -c ${2}`
    AssertNoIn "${phyTestResault}" "${phy_test_iperf3_10M}"     # 断言比较用例执行情况，若b中不包含a则通过

    testCaseId=02
    testCaseTitle="phy100Miperf3test" 
    phy_link_100M=`ethtool -s ${1} speed 100 duplex full autoneg on`
    sleep 3
    phy_test_iperf3_100M=`iperf3 -c ${2}`
    AssertNoIn "${phyTestResault}" "${phy_test_iperf3_100M}"    

    testCaseTitle="phy1000Miperf3test" 
    testCaseId=03
    phy_link_1000M=`ethtool -s ${1} speed 1000 duplex full autoneg on`
    sleep 3
    phy_test_iperf3_1000M=`iperf3 -c ${2}`
    AssertNoIn "${phyTestResault}" "${phy_test_iperf3_1000M}" 
}    

# 初始化函数
function PhyTestInit(){
    if [ "`whoami`" != "root" ]
    then
        read -p "请已root用户运行该脚本,点击Enter退出" end
        exit
    fi
    if test -f ./case.sh       # 判断是否存在用例模块
    then
        source ./case.sh       # 若存在用例模块则导入
        phytestnum="`cat ./case.sh|grep test_a|wc -l`"  # 若存在用例模块则获取用例数量并赋值给对应用例数量变量
    else
        phytestnum=0  # 若不存在用例模块则对应用例数量变量赋值为0
    fi
    # if test -f ./case/case_b.sh
    # then
    #     source ./case/case_b.sh
    #     num_b="`cat ./case/case_b.sh|grep test_b|wc -l`"
    # else
    #     num_b=0
    # fi
    # if test -f ./case/case_c.sh
    # then
    #     source ./case/case_c.sh
    #     num_c="`cat ./case/case_c.sh|grep test_c|wc -l`"
    # else
    #     num_c=0
    # fi
    gTestResault="pass"
    gFail=0 # 统计不通过用例数量
    gPass=0 # 统计通过用例数量
    gTotal=0 # 统计执行用例数量
    declare -a gFailId  # 定义失败用例ID数组变量
}

# 测试报告结束
function PhyTestReport(){
    testEnd=$(date +"%Y_%m_%d_%H_%M_%S")  # 获取测试结束时间
    echo "______________________________________________________________" >>  ${gReportPath} && cat ${gReportPath}| tail -1
    echo "" >>  ${gReportPath} && cat ${gReportPath}| tail -1
    echo "测试开始时间:${testStart}" >> ${gReportPath}    # 依次输出各关键信息
    echo "测试结束时间:${testEnd}" >> ${gReportPath}    
    echo "测试平台架构:`uname -m`" >> ${gReportPath}
    echo "执行用例合计:${gTotal}" >> ${gReportPath}
    echo "用例通过数量:${gPass}" >> ${gReportPath}
    echo "用例失败数量:${gFail}" >> ${gReportPath}
    echo "失败用例ID:${gFailId[*]}" >> ${gReportPath}
    cat ${gReportPath} | tail -7
    echo "______________________________________________________________" >>  ${gReportPath} && cat ${gReportPath}| tail -1
}

# 执行测试
function PhyTestStart(){
    PhyTestInit
    testStart=$(date +"%Y_%m_%d_%H_%M_%S")  # 获取当前时间戳并格式化
    report="report_${testStart}" && mkdir -p ./report && gReportPath=./report/${report} && touch ${gReportPath}  # 创建测试报告文件并赋值路径变量
    # sl
    # clear
    echo "______________________________________________________________" >>  ${gReportPath} && cat ${gReportPath}
    echo "" >>  ${gReportPath} && cat ${gReportPath}| tail -1    # 此类追加格式为追加内容进测试报告并展示在终端
    echo "                    # Phy测试开始 #                " >>  ${gReportPath} && cat ${gReportPath}| tail -1
    echo "        # 测试 Phy Link 10/100/1000M时的网速 #     " >>  ${gReportPath} && cat ${gReportPath}| tail -1
    # echo " # 测试例共计:              ${gTotal} #" >>  ${gReportPath} && cat ${gReportPath}| tail -1
    # echo " # 测试C: #" >>  ${gReportPath} && cat ${gReportPath}| tail -1
    echo "______________________________________________________________" >>  ${gReportPath} && cat ${gReportPath}| tail -1
    echo "" >>  ${gReportPath} && cat ${gReportPath}| tail -1
    printf "%-20s %-20s %20s\n" TESTID TESTRESAULT TESTTITLE >> ${gReportPath} && cat ${gReportPath}| tail -1   # 用例执行输出结果格式化

    if [ "${phytestnum}" == "0" ]
    then
        PhyLinkSpeedTestCase1 ${1} ${2} 
    fi    
    PhyTestReport
}

PhyTestStart ${1} ${2} 