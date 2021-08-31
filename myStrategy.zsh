#config
MY_ZSH_STRATEGY_VERSION=2.0
MY_ZSH_STRATEGY_ADDR="https://raw.githubusercontent.com/htprimer/mac_toolchain_configs/master/myStrategy.zsh"

_zsh_my_strategy_check() {
    curl $MY_ZSH_STRATEGY_ADDR -s > /tmp/myStrategy
    local version=$(cat /tmp/myStrategy | grep MY_ZSH_STRATEGY_VERSION | head -1)
    version=${version#*'='}
    if [[ -n "$version" ]] && (( $version > $MY_ZSH_STRATEGY_VERSION )) {
        cp /tmp/myStrategy $ZSH_CUSTOM/myStrategy.zsh
    }
}
((sleep 2; _zsh_my_strategy_check) &)

zshaddhistory() { whence ${${(z)1}[1]} >| /dev/null || return 1 }

ZSH_AUTOSUGGEST_STRATEGY=my_default

zle -N my_strategy_choose_hint_down _zsh_my_strategy_choose_hint_down
zle -N my_strategy_choose_hint_up _zsh_my_strategy_choose_hint_up
zle -N my_strategy_accept_hint _zsh_my_strategy_accept_hint

_zsh_autosuggest_strategy_my_default() {
    # Reset options to defaults and enable typeset_OPTIONS
    emulate -L zsh

    # Enable globbing flags so that we can use (#m)
    setopt EXTENDED_GLOB

	# Escape backslashes and all of the glob operators so we can use
	# this string as a pattern to search the $history associative array.
	# - (#m) globbing flag enables setting references for match data
	# TODO: Use (b) flag when we can drop support for zsh older than v5.0.8
    typeset prefix="${1//(#m)[\\*?[\]<>()|^~#]/\\$MATCH}"

    typeset -g suggestion
    suggestion=''
    typeset -g all_match_hint
    all_match_hint=()
    typeset -g current_line_index=0
    typeset -a input_array
    input_array=($(echo $prefix))

    if [[ $input_array[1] == 'cd' ]] {
        _zsh_my_strategy_cd_complete $input_array[2]  #cd 补全提示
    } elif [[ $input_array[1] == 'git' && $input_array[2] == 'checkout' ]] {
        _zsh_my_strategy_git_complete $input_array[3] #切分支补全
    } else {
        typeset hint=${history[(r)${prefix}*]}  #history是一个哈希表

        if [[ ${hint[(w)1]} == 'cd' ]] {
            _zsh_my_strategy_cd_complete   
        } elif [[ ${hint[(w)1]} == 'git' && ${hint[(w)2]} == 'checkout' ]] {
            _zsh_my_strategy_git_complete
        } else {
            [ -n "$(whence ${hint[(w)1]})" ] && suggestion="$hint"  #过滤无效记录
            if (( $#hint )) {
                all_match_hint=(${(u)history[(R)$prefix*]})
                all_match_hint=(${all_match_hint:#$hint})
                all_match_hint=(${all_match_hint:#$prefix})
                all_match_hint=($all_match_hint[1,10])
            }
        }
    }

    bindkey "^[OB" down-line-or-history
    bindkey "^[OA" up-line-or-history
    bindkey "^M" accept-line
    if (( $#all_match_hint )) {
        bindkey "^[OB" my_strategy_choose_hint_down
    }
    # Get the history items that match
    # - (r) subscript flag makes the pattern match on values
}

_zsh_my_strategy_git_complete() {
    typeset AllBranchs
    AllBranchs=($(git branch 2>&1))
    if [[ "$AllBranchs" == 'fatal'* ]] {
        return
    }
    typeset -A branchs
    # typeset -a todo_branchs
    # todo_branchs=($(git branch -r))
    #性能优化 远端分支数量太多则不匹配
    # if (( $#todo_branchs > 1000 )) {
    for branch_name ($AllBranchs) {
        if [[ $branch_name != '*' ]] {
            branchs[$branch_name]=$branch_name
        }
    }
    # }
    #  else {
    #     for origin_branch ($todo_branchs) {
    #         # local branch_name=${origin_branch#'origin/'}
    #         typeset branch_name=${origin_branch:7}
    #         if [[ $branch_name != 'HEAD'* ]] && [[ $branch_name != '->' ]] {
    #             branchs[$branch_name]=$branch_name
    #         }
    #     }
    # } 
    if (( $#1 >0 )) {
        typeset -a match_branchs
        match_branchs=(${branchs[(R)$1*]})
        for branch_name ($match_branchs) {
            all_match_hint+="git checkout $branch_name"
        }
    } else {
        for branch_name ($branchs) {
            all_match_hint+="git checkout $branch_name"
        }
    }
    all_match_hint=($all_match_hint[1,10])
    all_match_hint=(${(o)all_match_hint})
    suggestion="$all_match_hint[1]"
    all_match_hint=(${all_match_hint:#$suggestion})
}

_zsh_my_strategy_cd_complete() {
    typeset -A dirs  #用关联数组，R下标标志返回所有结果
    if (( $#1 > 0)) {
        typeset arg=$1
        typeset whole_arg=$arg
        typeset slash_index=$arg[(I)/]
        typeset dir=''
        if (( $slash_index > 0 && $slash_index != 1 )) {
            arg=$whole_arg[(($slash_index+1)),$#whole_arg]
            dir=$whole_arg[1,$slash_index]
            if [[ -d $dir ]] {
                dirs=()
                for file ($dir*) {
                    [[ -d $file ]] && dirs[$file]=$file
                }
                if (( $#arg <= 0 )) {
                    for file ($dirs) {
                        all_match_hint+="cd $file"
                    }
                    suggestion=''
                    return
                }
            }
        } else {
            typeset -a items
            items=($(ls))
            if (( $#items )) {  #判断是否空目录 避免*号报错
                for file (*) {
                    [[ -d $file ]] && dirs[$file]=$file 
                }
            }
        }
        typeset -a match_dirs #查找当前目录
        match_dirs=(${dirs[(R)$dir$arg*]}) 
        if (( $#match_dirs <= 0 )) {
            arg=${(U)arg} #转成大写尝试
            match_dirs=(${dirs[(R)$dir$arg*]})
            if (( $#match_dirs )) { BUFFER="cd $dir$arg" }
        } elif [[ "$arg" != "${(U)arg}" ]] {  #小写字母有结果 小写字母加入大写结果
            for file (${dirs[(R)$dir${(U)arg}*]}) {
                all_match_hint+="cd $file"
            }
        }
        if (( $#match_dirs )) {
            suggestion="cd $match_dirs[1]"
            for file ($match_dirs) {
                all_match_hint+="cd $file"
            }
            all_match_hint=(${all_match_hint:#$suggestion})
            all_match_hint=($all_match_hint[1,10])
        }
    } else {
        typeset -a items
        items=($(ls))
        if (( $#items )) {
            for file (*) {
                if [[ -d $file ]] {
                    dirs[$file]=$file
                    all_match_hint+="cd $file"
                }
            }
            suggestion="$all_match_hint[1]"  #优化成历史有且在当前目录 但是性能不好
            all_match_hint=(${all_match_hint:#$suggestion})
            all_match_hint=($all_match_hint[1,10])
        }
    }
}

_zsh_my_strategy_choose_hint_down() {
    bindkey "^[OA" my_strategy_choose_hint_up
    bindkey "^M" my_strategy_accept_hint
    (( current_line_index++ ))
    if (( $current_line_index > $#all_match_hint )) {
        current_line_index=1
    }
}

_zsh_my_strategy_choose_hint_up() {
    (( current_line_index-- ))
    if (( $current_line_index <= 0 )) {
        current_line_index=$#all_match_hint
    }
}

_zsh_my_strategy_accept_hint() {
    BUFFER="$all_match_hint[$current_line_index]"
    CURSOR=$#BUFFER
    bindkey "^M" accept-line
    unset all_match_hint
}

#重写高亮方法
_zsh_autosuggest_highlight_reset() {
	typeset -g _ZSH_AUTOSUGGEST_LAST_HIGHLIGHT

	if [[ -n "$_ZSH_AUTOSUGGEST_LAST_HIGHLIGHT" ]]; then
		# region_highlight=("${(@)region_highlight:#$_ZSH_AUTOSUGGEST_LAST_HIGHLIGHT}")
        region_highlight=()
		unset _ZSH_AUTOSUGGEST_LAST_HIGHLIGHT
	fi
}

_zsh_autosuggest_highlight_apply() {
	typeset -g _ZSH_AUTOSUGGEST_LAST_HIGHLIGHT
    
	if (( $#POSTDISPLAY )); then
		typeset -g _ZSH_AUTOSUGGEST_LAST_HIGHLIGHT="$#BUFFER $(($#BUFFER + $#POSTDISPLAY)) $ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE"
		region_highlight+=("$_ZSH_AUTOSUGGEST_LAST_HIGHLIGHT")
        
        if (( $current_line_index > 0 )) {
            typeset line=$'\n'
            typeset current_line_start=$(($#BUFFER + $#right_hint + $#line))
            for i ($all_match_hint[1,$((current_line_index-1))]) {
                (( current_line_start+=$#i ))
                (( current_line_start+=$#line ))
            }
            typeset current_line=$all_match_hint[$current_line_index]
            typeset current_hint_highlight="$current_line_start $(($current_line_start + $#current_line)) fg=209,bg=8,bold"
            region_highlight+=("$current_hint_highlight")
        }
	else
		unset _ZSH_AUTOSUGGEST_LAST_HIGHLIGHT
	fi
}

#重写显示方法
_zsh_autosuggest_suggest() {
    typeset suggestion="$1"

    if [[ -n "$suggestion" ]] && (( $#BUFFER )); then
        typeset -g right_hint="${suggestion#$BUFFER}"
        typeset all_hint=$'\n'"$(print -l $all_match_hint)"
        POSTDISPLAY="$right_hint$all_hint"
        # POSTDISPLAY="${suggestion#$BUFFER}"
    elif (( $#all_match_hint )); then
        typeset -g right_hint=''
        POSTDISPLAY=$'\n'"$(print -l $all_match_hint)"
    else
        unset right_hint 
        unset POSTDISPLAY
        unset all_match_hint
    fi
}

#重写接受方法
_zsh_autosuggest_accept() {
    typeset -i max_cursor_pos=$#BUFFER

    # When vicmd keymap is active, the cursor can't move all the way
    # to the end of the buffer
    if [[ "$KEYMAP" = "vicmd" ]]; then
        max_cursor_pos=$((max_cursor_pos - 1))
    fi

    # Only accept if the cursor is at the end of the buffer
    if [[ $CURSOR = $max_cursor_pos ]]; then
        # Add the suggestion to the buffer
        # BUFFER="$BUFFER$POSTDISPLAY"
        BUFFER="$BUFFER$right_hint"

        # Remove the suggestion
        unset POSTDISPLAY
        unset right_hint 
        unset all_match_hint

        # Move the cursor to the end of the buffer
        CURSOR=${#BUFFER}
        #接收补全后重置方向键
        bindkey "^[OB" down-line-or-history
        bindkey "^[OA" up-line-or-history
        bindkey "^M" accept-line
    fi

    _zsh_autosuggest_invoke_original_widget $@
}

#重写modify方法
_zsh_autosuggest_modify() {
    typeset -i retval

    # Only available in zsh >= 5.4
    typeset -i KEYS_QUEUED_COUNT

    # Save the contents of the buffer/postdisplay
    typeset orig_buffer="$BUFFER"
    typeset orig_postdisplay="$POSTDISPLAY"

    # Clear suggestion while waiting for next one
    unset POSTDISPLAY

    # Original widget may modify the buffer
    _zsh_autosuggest_invoke_original_widget $@
    retval=$?

    # Don't fetch a new suggestion if there's more input to be read immediately
    if (( $PENDING > 0 )) || (( $KEYS_QUEUED_COUNT > 0 )); then
        return $retval
    fi

    # Optimize if manually typing in the suggestion
    if (( $#BUFFER > $#orig_buffer )); then
        typeset added=${BUFFER#$orig_buffer}

        # If the string added matches the beginning of the postdisplay
        if [[ "$added" = "${orig_postdisplay:0:$#added}" ]]; then
            POSTDISPLAY="${orig_postdisplay:$#added}"
            right_hint="${right_hint:$#added}" #更新补全
            _zsh_autosuggest_fetch
            return $retval
        fi
    fi

    # Don't fetch a new suggestion if the buffer hasn't changed
    if [[ "$BUFFER" = "$orig_buffer" ]]; then
        POSTDISPLAY="$orig_postdisplay"
        return $retval
    fi

    # Bail out if suggestions are disabled
    if [[ -n "${_ZSH_AUTOSUGGEST_DISABLED+x}" ]]; then
        return $?
    fi

    # Get a new suggestion if the buffer is not empty after modification
    if (( $#BUFFER > 0 )); then
        if [[ -z "$ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE" ]] || (( $#BUFFER <= $ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE )); then
            _zsh_autosuggest_fetch
        fi
    fi

    return $retval
}

# 重写fetch方法
_zsh_autosuggest_fetch_suggestion() {
	typeset -g suggestion
	local -a strategies
	local strategy

	# Ensure we are working with an array
	strategies=(${=ZSH_AUTOSUGGEST_STRATEGY})

	for strategy in $strategies; do
		# Try to get a suggestion from this strategy
		_zsh_autosuggest_strategy_$strategy "$1"

		# Ensure the suggestion matches the prefix
        # 让 suggestion 与当前 buffer 比较，因为buffer可能会被改动
		[[ "$suggestion" != "$BUFFER"* ]] && unset suggestion

		# Break once we've found a valid suggestion
		[[ -n "$suggestion" ]] && break
	done
}
