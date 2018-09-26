#config
MY_ZSH_STRATEGY_VERSION=1.2
MY_ZSH_STRATEGY_ADDR="https://raw.githubusercontent.com/htprimer/mac_toolchain_configs/master/myStrategy.zsh"

_zsh_my_strategy_check() {
    curl $MY_ZSH_STRATEGY_ADDR -s > /tmp/myStrategy
    local version=$(cat /tmp/myStrategy | grep MY_ZSH_STRATEGY_VERSION | head -1)
    version=${version#*'='}
    if [[ -n "$version" ]] && (( $version > $MY_ZSH_STRATEGY_VERSION )) {
        cp /tmp/myStrategy $ZSH_CUSTOM/myStrategy.zsh
    }
}
_zsh_my_strategy_check

zshaddhistory() { whence ${${(z)1}[1]} >| /dev/null || return 1 }

ZSH_AUTOSUGGEST_STRATEGY=my_default

zle -N my_strategy_choose_hint_down _zsh_my_strategy_choose_hint_down
zle -N my_strategy_choose_hint_up _zsh_my_strategy_choose_hint_up
zle -N my_strategy_accept_hint _zsh_my_strategy_accept_hint

_zsh_autosuggest_strategy_my_default() {
    # Reset options to defaults and enable LOCAL_OPTIONS
    emulate -L zsh

    # Enable globbing flags so that we can use (#m)
    setopt EXTENDED_GLOB

	# Escape backslashes and all of the glob operators so we can use
	# this string as a pattern to search the $history associative array.
	# - (#m) globbing flag enables setting references for match data
	# TODO: Use (b) flag when we can drop support for zsh older than v5.0.8
    local prefix="${1//(#m)[\\*?[\]<>()|^~#]/\\$MATCH}"
    if [[ $prefix = ' '* ]] || [[ $prefix = '\t'* ]] {
        return
    }

    local cmd=${${(z)prefix}[1]}
    local arg=${${(z)prefix}[2]}
    local -A dirs=()  #用关联数组，R下标标志返回所有结果

    typeset -g all_match_hint=()

    local blank=' '
    if (( $prefix[(I)$blank] > 0 )) {
        if [[ "$cmd" == 'cd' ]] {
            for file (*) { 
                if [ -d $file ]; then
                    dirs[$file]=$file
                fi
            }
            local match_dirs=(${dirs[(R)$arg*]})  #查找当前目录
            if (( $#match_dirs <= 0 )) {
                arg=${(U)arg} #转成大写尝试
                match_dirs=(${dirs[(R)$arg*]})
                if (( $#match_dirs )) { 
                    BUFFER="cd $arg"
                }
            } elif [[ "$arg" != "${(U)arg}" ]] {  #小写字母有结果 小写字母加入大写结果
                for file in ${dirs[(R)${(U)arg}*]}; do
                    all_match_hint+="cd $file"
                done
            }
            if (( $#match_dirs )) {
                typeset -g suggestion="cd $match_dirs[1]"
                for file in $match_dirs; do
                    all_match_hint+="cd $file"
                done
                all_match_hint=(${all_match_hint:#$suggestion})
                all_match_hint=($all_match_hint[1,10])
                return
            }
        }
    } else {  #无参数
        if [[ "$prefix" == 'cd' ]] {
            for file (*) {
                if [ -d $file ]; then
                    dirs[$file]=$file
                    all_match_hint+="cd $file"
                fi
            }
            typeset -g suggestion="$all_match_hint[1]"  #优化成历史有且在当前目录 但是性能不好
            all_match_hint=(${all_match_hint:#$suggestion})
            all_match_hint=($all_match_hint[1,10])
            return
        }
    }

    local hint=${history[(r)${prefix}*]}  #history是一个哈希表
    if (( $#hint )) {
        all_match_hint=(${(u)history[(R)$prefix*]})
        all_match_hint=(${all_match_hint:#$hint})
        all_match_hint=(${all_match_hint:#$prefix})
        all_match_hint=($all_match_hint[1,10])
    }

    #过滤无效记录
    typeset -g suggestion=""
    if (( $hint[(I)$blank] > 0 )); then
        [ -n "$(whence ${${(z)hint}[1]})" ] && typeset -g suggestion="$hint"
    else
        [ -n "$(whence $hint)" ] && typeset -g suggestion="$hint"
    fi
    #如果是历史记录是cd命令且目标目录不在当前目录下，则移除此提示
    if (( $#suggestion )) && (( $suggestion[(I)$blank] )) && [[ ${${(z)suggestion}[1]} == 'cd' ]] {
        local dir=${${(z)suggestion}[2]}
        dir="${dirs[(r)$dir]}"
        (( $#dir == 0 )) && typeset -g suggestion=""
    }
    if (( $#suggestion <= 0 )) && (( $#prefix >= 5 )) {  #开启模糊匹配
        local pattern='*'
        for i ({1..$#prefix}); do
            pattern+="$prefix[i]*"
        done
        all_match_hint=(${(u)history[(R)$pattern]})
        all_match_hint=($all_match_hint[1,10])
        # echo $pattern
        # echo $all_match_hint
    }

    bindkey "^[OB" down-line-or-history
    bindkey "^[OA" up-line-or-history
    bindkey "^M" accept-line
    if (( $#all_match_hint )) {
        bindkey "^[OB" my_strategy_choose_hint_down
        typeset -g current_line_index=0
    }
    # Get the history items that match
    # - (r) subscript flag makes the pattern match on values
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
            local line=$'\n'
            local current_line_start=$(($#BUFFER + $#right_hint + $#line))
            for i ($all_match_hint[1,$((current_line_index-1))]) {
                (( current_line_start+=$#i ))
                (( current_line_start+=$#line ))
            }
            local current_line=$all_match_hint[$current_line_index]
            local current_hint_highlight="$current_line_start $(($current_line_start + $#current_line)) fg=magenta,bg=8,bold"
            region_highlight+=("$current_hint_highlight")
        }
	else
		unset _ZSH_AUTOSUGGEST_LAST_HIGHLIGHT
	fi
}

#重写显示方法
_zsh_autosuggest_suggest() {
    local suggestion="$1"

    if [[ -n "$suggestion" ]] && (( $#BUFFER )); then
        typeset -g right_hint="${suggestion#$BUFFER}"
        local all_hint=$'\n'"$(print -l $all_match_hint)"
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
    local -i max_cursor_pos=$#BUFFER

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
    local -i retval

    # Only available in zsh >= 5.4
    local -i KEYS_QUEUED_COUNT

    # Save the contents of the buffer/postdisplay
    local orig_buffer="$BUFFER"
    local orig_postdisplay="$POSTDISPLAY"

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
        local added=${BUFFER#$orig_buffer}

        # If the string added matches the beginning of the postdisplay
        if [[ "$added" = "${orig_postdisplay:0:$#added}" ]]; then
            POSTDISPLAY="${orig_postdisplay:$#added}"
            right_hint="${right_hint:$#added}" #更新补全
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
