" Plugin and variable setup ------ {{{
if exists("g:investigate_loaded_defaults")
  finish
endif
let g:investigate_loaded_defaults = 1

let s:dashString    = 0
let s:searchURL     = 1
let s:customCommand = 2
" }}}

" Default language settings ------ {{{
let s:defaultLocations = {
  \ "c": ["c", "http://en.cppreference.com/mwiki/index.php?search=%s"],
  \ "cpp": ["cpp", "http://en.cppreference.com/mwiki/index.php?search=%s"],
  \ "go": ["go", "http://golang.org/search?q=%s"],
  \ "objc": ["macosx", "https://developer.apple.com/search/index.php?q=%s"],
  \ "php": ["php", "http://us3.php.net/results.php?q=%s"],
  \ "python":["python", "http://docs.python.org/2/search.html?q=%s"],
  \ "ruby": ["ruby", "http://ruby-doc.com/search.html?q=%s"],
  \ "vim": ["vim", "http://vim.wikia.com/wiki/Special:Search?search=%s", "%i:h %s"]
\ }
" }}}

" Check to make sure the language is supported ------ {{{
"   if not echo an error message
function! s:HasKeyForFiletype(filetype)
  if has_key(s:defaultLocations, a:filetype)
    return 1
  else
    echomsg "No documentation for " . a:filetype
    return 0
  endif
endfunction
" }}}

" Check for custom commands specific to the language ------ {{{
function! s:CustomCommandVariableForFiletype(filetype)
  return "g:investigate_command_for_" . a:filetype
endfunction

function! s:CustomCommandVariableKeyForFiletype(filetype)
  return expand(g:investigate_command_for_{a:filetype})
endfunction

function! s:HasCustomCommandForFiletype(filetype)
  if (has_key(s:defaultLocations, a:filetype) && len(s:defaultLocations[a:filetype]) > 2) || exists(s:CustomCommandVariableForFiletype(a:filetype))
    return 1
  endif

  return 0
endfunction

function! s:CustomCommandForFiletype(filetype)
  if exists(s:CustomCommandVariableForFiletype(a:filetype))
    return s:CustomCommandVariableKeyForFiletype(a:filetype)
  elseif s:HasKeyForFiletype(a:filetype)
    return s:defaultLocations[a:filetype][s:customCommand]
  endif
endfunction
" }}}

" Custom local file reading ------ {{{
function! s:LoadFolderSpecificSettings()
  " Only load the file once
  if exists("g:investigate_loaded_local")
    return
  endif
  let g:investigate_loaded_local = 1
  echomsg "1"

  " Get the local file path and make sure it exists
  let l:filename = getcwd() . "/.investigaterc"
  if glob(l:filename) == ""
    return
  endif

  let l:contents = s:ReadAndCleanFile(l:filename)
  let l:commands = s:ParseRCFileContents(l:contents)
  for l:command in l:commands
    echomsg "Adding: " . l:command
    exec l:command
  endfor
endfunction

" Return a list of commands parsed and formatted correctly
function! s:ParseRCFileContents(contents)
  let l:commands = []
  let l:identifier = ""
  for l:line in a:contents
    " Attempt to get the identifier string from the line
    let l:identifierString = s:IdentifierFromString(l:line)

    " If the string isn't an identifier
    if l:identifierString == ""
      " Get the end of the command string
      let l:command = s:MatchForString(l:line)
      if l:command == ""
        " Print an error if the syntax is invalid
        echomsg "Invalid syntax: '" . l:line . "'"
      elseif l:identifier == ""
        " Print an error if no identifier has come before this line
        echomsg "No previous identifier: " . l:line
      else
        " Build the entire command
        let l:fullCommand = "let g:investigate_" . l:identifier . "_for_" . l:command
        call add(l:commands, l:fullCommand)
      endif
    else
      let l:identifier = l:identifierString
    endif
  endfor

  return l:commands
endfunction

" Read the given filepath line by line
" Trim all whitespace and ignore blank lines
" Returns a list of the remaining lines
" [dash]\n\nruby=rails -> ['[dash]', 'ruby=rails']
function! s:ReadAndCleanFile(filepath)
  let l:final = []
  let l:contents = readfile(a:filepath)
  for l:line in l:contents
    let l:trimmed = substitute(l:line, "\\s", "", "g")
    if l:trimmed != ""
      call add(l:final, l:trimmed)
    endif
  endfor

  return l:final
endfunction


" Return the end of the identifier string
" ruby = rails -> ruby='rails'
" ruby = rails = cpp -> ""
" ruby -> ""
function! s:MatchForString(string)
  " Make sure there is only a single = in the string
  if count(split(a:string, "\\zs"), "=") != 1
    return ""
  endif

  let l:parts = split(a:string, "\\s*=\\s*")
  return l:parts[0] . "='" . l:parts[1] . "'"
endfunction

" Get the function identifier for the passed string
" [dash] -> dash
" dash -> ""
function! s:IdentifierFromString(string)
  if strpart(a:string, 0, 1) == "[" && strpart(a:string, len(a:string) - 1, 1) == "]"
    return strpart(a:string, 1, len(a:string) - 2)
  endif

  return ""
endfunction
" }}}

" Choose file command based on custom, dash or URL ------ {{{
function! g:SearchStringForFiletype(filetype, forDash)
  call s:LoadFolderSpecificSettings()

  if s:HasCustomCommandForFiletype(a:filetype)
    return s:CustomCommandForFiletype(a:filetype)
  elseif a:forDash
    return s:DashStringForFiletype(a:filetype)
  else
    return "\"" . s:URLForFiletype(a:filetype) . "\""
  endif
endfunction
" }}}

" Dash configuration ------ {{{
function! s:CustomDashStringForFiletype(filetype)
  return "g:investigate_dash_for_" . a:filetype
endfunction

function! s:CustomDashKeyForFiletype(filetype)
  return expand(g:investigate_dash_for_{a:filetype})
endfunction

function! s:DashStringForFiletype(filetype)
  let l:string = ""
  if exists(s:CustomDashStringForFiletype(a:filetype))
    let l:string = s:CustomDashKeyForFiletype(a:filetype)
  elseif s:HasKeyForFiletype(a:filetype)
    let l:string = s:defaultLocations[a:filetype][s:dashString]
  endif

  if l:string != ""
    let l:string .= ":%s"
  endif
  return l:string
endfunction
" }}}

" URL configuration ------ {{{
function! s:CustomURLStringForFiletype(filetype)
  return "g:investigate_url_for_" . a:filetype
endfunction

function! s:CustomURLKeyForFiletype(filetype)
  return expand(g:investigate_url_for_{a:filetype})
endfunction

function! s:URLForFiletype(filetype)
  if exists(s:CustomURLStringForFiletype(a:filetype))
    return s:CustomURLKeyForFiletype(a:filetype)
  elseif s:HasKeyForFiletype(a:filetype)
    return s:defaultLocations[a:filetype][s:searchURL]
  endif
endfunction
" }}}

