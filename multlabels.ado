* =============================================================
/* Author Information */
* Name:        ZHU Kunjie（朱昆杰）
* Email:       aaronzhu211@gmail.com
* Affiliation: University of Chinese Academy of Sciences
* Date:        2025/2/4
* Version:     V1.0
* =============================================================

cap program drop multlabels
program define multlabels
    syntax varlist(min=1), labellist(string) [rename(string)]
    local labellist `labellist'
    local labcount : word count `labellist'
    local varcount : word count `varlist'

    if `labcount' != `varcount' {
        di as error "变量数量和标签数量不匹配"
        exit 198
    }

    * 为变量添加标签
    local i 1
    foreach var of varlist `varlist' {
        local label : word `i' of `labellist'
        label variable `var' "`label'"
        local i = `i' + 1
    }

    * 检查是否提供了重命名选项
    if "`rename'" != "" {
        local renamecount : word count `rename'
        if `renamecount' != `varcount' {
            di as error "变量数量和重命名列表数量不匹配"
            exit 198
        }
        * 执行重命名操作
        local i 1
        foreach var of varlist `varlist' {
            local newname : word `i' of `rename'
            rename `var' `newname'
            local i = `i' + 1
        }
    }
end