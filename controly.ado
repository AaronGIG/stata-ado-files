* controly.ado
capture program drop controly
program controly
    version 16
	syntax , yvar(varlist) xvar(varlist) [x1vars(varlist) fixed_xvars(varlist) fixed_vars(varlist) controls(varlist) absorb(varlist) vce(passthru) sig_x(real 0.05) sig_x1(real 0.05) sig_fixedx(real 0.05) filename(string)]
	    
	* 校验显著性参数有效性
	foreach param in sig_x sig_x1 sig_fixedx {
		if (``param'' <=0 | ``param'' >=1) & "``param''" != "0.05" { // 允许默认值以外的自定义值
			di as error "参数 `param' 必须填写0到1之间的数值"
			exit 198
		}
	}
    * 处理文件名参数
    if `"`filename'"' != "" {
        local filename = subinstr(`"`filename'"', ".xlsx", "", .)
        local excelfile "`filename'.xlsx"
    }
    else {
        local excelfile "Controly_Results.xlsx"
    }
    capture erase "`excelfile'"
    
    * 变量组独立性校验
    foreach group in x1vars fixed_xvars fixed_vars {
        foreach pair in x1vars fixed_xvars x1vars fixed_vars fixed_xvars fixed_vars {
            if "`group'" == "`pair'" continue
            local conflict : list `group' & `pair'
            if "`conflict'" != "" {
                di as error "变量组冲突：`group' 与 `pair' 存在重复变量 `conflict'"
                exit 198
            }
        }
    }
    
    * 循环处理每个因变量
    local yindex 0
    foreach y of local yvar {
        local yindex = `yindex' + 1
        
        * 循环处理每个核心自变量
        foreach x of local xvar {
            di _n(2) "=============== 开始分析：因变量`yindex'=`y' 核心变量=`x' ==============="
            
            * 生成控制变量组合
            local n_controls : word count `controls'
            local total_combinations = cond(`n_controls'>0, 2^`n_controls' - 1, 1)
            
            * 创建临时存储
            tempname results
            tempfile tempresults
            postfile `results' str2045(varlist) double(coeff se pvalue) using "`tempresults'", replace
            
            * 遍历所有组合
            forvalues mask = 0/`total_combinations' {
                * 生成当前controls组合
                local current_controls
                forvalues i = 1/`n_controls' {
                    local bit = mod(floor(`mask'/(2^(`i'-1))),2)
                    if `bit' {
                        local var : word `i' of `controls'
                        local current_controls `current_controls' `var'
                    }
                }
                
                * 执行回归（强制包含所有变量组）
                capture noisily {
                    qui reghdfe `y' `x' `x1vars' `fixed_xvars' `fixed_vars' `current_controls', ///
                        absorb(`absorb') `vce'
                    
                    matrix tab = r(table)
                    local colnames : colnames tab
                    local valid = 1  // 有效性标记
                    
                    * 条件1：核心变量必须显著（使用sig_x阈值）
                    if strpos(" `colnames' ", " `x' ") {
                        scalar p_val_x = tab["pvalue", "`x'"]
                        if p_val_x > `sig_x' local valid 0
                    }
                    else {
                        di as error "核心变量 `x' 缺失！"
                        local valid 0
                    }
                    
                    * 条件2：x1vars必须全部显著（使用sig_x1阈值）
                    foreach var in `x1vars' {
                        if strpos(" `colnames' ", " `var' ") {
                            scalar p_val_x1 = tab["pvalue", "`var'"]
                            if p_val_x1 > `sig_x1' {
                                local valid 0
                                continue, break
                            }
                        }
                        else {
                            di as error "x1vars变量 `var' 缺失！"
                            local valid 0
                            continue, break
                        }
                    }
                    
                    * 条件3：fixed_xvars必须全部不显著（使用sig_fixedx阈值）
                    foreach var in `fixed_xvars' {
                        if strpos(" `colnames' ", " `var' ") {
                            scalar p_val_fx = tab["pvalue", "`var'"]
                            if p_val_fx <= `sig_fixedx' {
                                local valid 0
                                continue, break
                            }
                        }
                        else {
                            di as error "fixed_xvars变量 `var' 缺失！"
                            local valid 0
                            continue, break
                        }
                    }
                    
                    * 记录有效结果
                    if `valid' {
                        scalar coeff_val = tab["b", "`x'"]
                        scalar se_val = tab["se", "`x'"]
                        scalar p_val = tab["pvalue", "`x'"]
                        post `results' ("x1vars: `x1vars' || fixed_xvars: `fixed_xvars' || fixed_vars: `fixed_vars' || controls: `current_controls'") ///
                            (coeff_val) (se_val) (p_val)
                    }
                }
                if _rc di as error "组合 `current_controls' 计算错误，已跳过"
            }
            
            * 导出到Excel
            postclose `results'
            preserve
            use "`tempresults'", clear
            if _N > 0 {
                local sheetname = substr("`x'_`y'", 1, 31)
                export excel "`excelfile'", sheet("`sheetname'") sheetreplace firstrow(varlabels) cell(A2)
                di "成功保存 `=_N' 个有效组合到工作表 `sheetname'"
            }
            else {
                di as text "无有效组合"
            }
            restore
        }
    }
    
    * 生成可点击文件路径
    local fullpath = subinstr("`c(pwd)'", "/", "\", .) + "\`excelfile'"
    di _n(2) `"分析完成！结果文件：{browse "`fullpath'":点击打开}"'
end