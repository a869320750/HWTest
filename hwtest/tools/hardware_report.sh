#!/bin/bash
# filepath: hardware_report.sh
# 硬件综合体检报告生成器

REPORT_DIR="/tmp/hw_report_$(date +%Y%m%d_%H%M%S)"
HTML_REPORT="$REPORT_DIR/hardware_report.html"

generate_html_report() {
    mkdir -p "$REPORT_DIR"
    
    cat > "$HTML_REPORT" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RK3588硬件体检报告</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .header h1 { color: #2c3e50; margin-bottom: 10px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .summary-card { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; text-align: center; }
        .summary-card h3 { margin: 0 0 10px 0; font-size: 18px; }
        .summary-card .number { font-size: 36px; font-weight: bold; margin: 10px 0; }
        .test-section { margin-bottom: 30px; }
        .test-section h2 { color: #34495e; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        .test-item { display: flex; justify-content: space-between; align-items: center; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .test-pass { background: #d4edda; border-left: 4px solid #28a745; }
        .test-fail { background: #f8d7da; border-left: 4px solid #dc3545; }
        .test-skip { background: #fff3cd; border-left: 4px solid #ffc107; }
        .status { font-weight: bold; padding: 5px 15px; border-radius: 20px; color: white; }
        .status-pass { background: #28a745; }
        .status-fail { background: #dc3545; }
        .status-skip { background: #ffc107; }
        .details { margin-top: 20px; }
        .details-table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        .details-table th, .details-table td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        .details-table th { background: #f8f9fa; font-weight: bold; }
        .footer { text-align: center; margin-top: 30px; color: #6c757d; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔧 RK3588硬件体检报告</h1>
            <p>生成时间: $(date '+%Y年%m月%d日 %H:%M:%S')</p>
            <p>设备信息: $(hostname) | $(uname -r)</p>
        </div>

        <div class="summary">
            <div class="summary-card">
                <h3>总测试项</h3>
                <div class="number" id="total-tests">0</div>
                <p>硬件模块</p>
            </div>
            <div class="summary-card">
                <h3>通过</h3>
                <div class="number" id="passed-tests">0</div>
                <p>正常工作</p>
            </div>
            <div class="summary-card">
                <h3>失败</h3>
                <div class="number" id="failed-tests">0</div>
                <p>需要检查</p>
            </div>
            <div class="summary-card">
                <h3>成功率</h3>
                <div class="number" id="success-rate">0%</div>
                <p>整体状态</p>
            </div>
        </div>

        <div class="test-section">
            <h2>📋 硬件模块测试结果</h2>
            <div id="test-results">
                <!-- 测试结果将在这里插入 -->
            </div>
        </div>

        <div class="details">
            <h2>📊 系统详细信息</h2>
            <table class="details-table">
                <tr><th>CPU信息</th><td id="cpu-info">检测中...</td></tr>
                <tr><th>内存信息</th><td id="memory-info">检测中...</td></tr>
                <tr><th>存储信息</th><td id="storage-info">检测中...</td></tr>
                <tr><th>网络接口</th><td id="network-info">检测中...</td></tr>
                <tr><th>USB设备</th><td id="usb-info">检测中...</td></tr>
                <tr><th>GPIO状态</th><td id="gpio-info">检测中...</td></tr>
            </table>
        </div>

        <div class="footer">
            <p>报告由 HWTest 硬件测试工具生成 | 版本 v2.0</p>
        </div>
    </div>

    <script>
        // 这里可以添加JavaScript来动态更新数据
        function updateTestResult(name, status, details) {
            const container = document.getElementById('test-results');
            const statusClass = status === 'pass' ? 'test-pass' : status === 'fail' ? 'test-fail' : 'test-skip';
            const statusText = status === 'pass' ? '通过' : status === 'fail' ? '失败' : '跳过';
            const statusBadgeClass = status === 'pass' ? 'status-pass' : status === 'fail' ? 'status-fail' : 'status-skip';
            
            container.innerHTML += `
                <div class="test-item ${statusClass}">
                    <div>
                        <strong>${name}</strong>
                        <div style="font-size: 14px; color: #6c757d;">${details}</div>
                    </div>
                    <span class="status ${statusBadgeClass}">${statusText}</span>
                </div>
            `;
        }

        function updateSummary(total, passed, failed) {
            document.getElementById('total-tests').textContent = total;
            document.getElementById('passed-tests').textContent = passed;
            document.getElementById('failed-tests').textContent = failed;
            const rate = total > 0 ? Math.round((passed / total) * 100) : 0;
            document.getElementById('success-rate').textContent = rate + '%';
        }

        function updateSystemInfo() {
            // 更新系统信息
            fetch('/proc/cpuinfo').then(r => r.text()).then(data => {
                document.getElementById('cpu-info').textContent = data.split('\n')[0] || '未知';
            }).catch(() => {
                document.getElementById('cpu-info').textContent = '$(cat /proc/cpuinfo | head -1 | cut -d: -f2)';
            });
        }
    </script>
</body>
</html>
EOF

    echo "HTML报告已生成: $HTML_REPORT"
}

# 生成报告
generate_html_report
