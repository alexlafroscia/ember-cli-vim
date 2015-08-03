" autoload/ember.vim
" Author: Alex LaFroscia

if exists('g:autoloaded_ember') || &cp
  finish
endif
let g:autoloaded_ember = 1

" Configure User Settings {{{1

" Check if we should allow Vim configuration
if !exists("g:ember_config_vim")
  let g:ember_config_vim = 1
endif

if !exists("g:ember_config_vim_suffixesadd")
  let g:ember_config_vim_suffixesadd = 1
endif

" }}}1

" Utility Functions {{{1

function! s:makeAndSwitch(command, ...)
  let default_makeprg = &makeprg
  let args = join(a:000, " ")

  echom 'command: ' . a:command
  echom 'args: ' . args

  " Run command with arguments
  if !len(a:000)
    let &makeprg = a:command
  else
    let &makeprg = a:command . " " . args
  endif

  " Execute the command
  if exists(':Make') == 2
    exe 'Make'
  else
    exe 'make'
  endif

  " Restore previous behavior
  let &makeprg = default_makeprg
endfunction

function! s:makeAndSwitchTests(command, ...)
  " TODO: filter/format output
  call s:makeAndSwitch(a:command, join(a:000, ' '))
endfunction

" Get the types of files that can be generated by Ember
" Does not currently support blueprints provided by addons
function! ember#get_blueprints()
  let blueprint_path = g:ember_root . '/node_modules/ember-cli/blueprints'
  let blueprints = split(globpath(blueprint_path, '*'), '\n')
  let truncated_names = []
  for file in blueprints
    let truncated_names += [file[strlen(blueprint_path . '/') : -1]]
  endfor
  return truncated_names
endfunction

" Given a type, return the directory name associated with it
function! ember#get_directory_for_type(type)
  if a:type =~ 'acceptance-test'
    return 'tests/acceptance'
  elseif a:type =~ 'component-test'
    return 'tests/integration/components'
  elseif a:type =~ '-test'
    return 'tests/unit/' . a:type[0 : -6] . 's'
  else
    return 'app/' . a:type . 's'
  endif
endfunction

" Given a type, return a list of the names of all the files of that type
"   Example: arg -> 'controller'
"   Return:  ['users/user']
function! s:get_files_for_type(type)
  let path = g:ember_root . '/' . ember#get_directory_for_type(a:type)
  let files = split(globpath(path, '**/*.js'), '\n')
  let relative_files = []
  for file in files
    " Add the file path to the array
    let filename = file[strlen(path . '/') : -strlen('.js') - 1]
    " Parse out the directory and add that to the array
    let index = strridx(filename, '/')
    if index != -1
      let filename = filename[filename : index - 1]
      let relative_files += [filename]
    endif
    let relative_files += [file[strlen(path . '/') : -strlen('.js') - 1]]
  endfor
  return relative_files
endfunction

" Filter a list for completion results | Shamelessly borrowed from rails.vim
" https://github.com/tpope/vim-rails/blob/12addfcaf5ce97632adbb756bea76cb970dea002/autoload/rails.vim#L2522-L2543
function! s:completion_filter(results, A, ...) abort
  let results = s:uniq(sort(type(a:results) == type("") ? split(a:results,"\n") : copy(a:results)))
  call filter(results,'v:val !~# "\\~$"')
  if a:A =~# '\*'
    let regex = s:gsub(a:A,'\*','.*')
    return filter(copy(results),'v:val =~# "^".regex')
  endif
  let filtered = filter(copy(results),'s:startswith(v:val,a:A)')
  if !empty(filtered) | return filtered | endif
  let prefix = s:sub(a:A,'(.*[/]|^)','&_')
  let filtered = filter(copy(results),"s:startswith(v:val,prefix)")
  if !empty(filtered) | return filtered | endif
  let regex = s:gsub(a:A,'[^/]','[&].*')
  let filtered = filter(copy(results),'v:val =~# "^".regex')
  if !empty(filtered) | return filtered | endif
  let regex = s:gsub(a:A,'.','[&].*')
  let filtered = filter(copy(results),'v:val =~# regex')
  return filtered
endfunction

" Remove duplicates from list | Shamelessly borrowed from rails.vim
" https://github.com/tpope/vim-rails/blob/12addfcaf5ce97632adbb756bea76cb970dea002/autoload/rails.vim#L44-L59
function! s:uniq(list) abort
  let i = 0
  let seen = {}
  while i < len(a:list)
    if (a:list[i] ==# '' && exists('empty')) || has_key(seen,a:list[i])
      call remove(a:list,i)
    elseif a:list[i] ==# ''
      let i += 1
      let empty = 1
    else
      let seen[a:list[i]] = 1
      let i += 1
    endif
  endwhile
  return a:list
endfunction

" Does some string start with some prefix? | Shamelessly borrowed from rails.vim
" https://github.com/tpope/vim-rails/blob/12addfcaf5ce97632adbb756bea76cb970dea002/autoload/rails.vim#L36-L38
function! s:startswith(string,prefix)
  return strpart(a:string, 0, strlen(a:prefix)) ==# a:prefix
endfunction

function! s:equal(string1, string2)
  return a:string1 ==? a:string2
endfunction

" sub | Shamelessly borrowed from rails.vim
" https://github.com/tpope/vim-rails/blob/12addfcaf5ce97632adbb756bea76cb970dea002/autoload/rails.vim#L28-L30
function! s:sub(str,pat,rep)
  return substitute(a:str,'\v\C'.a:pat,a:rep,'')
endfunction

" gsub | Shamelessly borrowed from rails.vim
" https://github.com/tpope/vim-rails/blob/12addfcaf5ce97632adbb756bea76cb970dea002/autoload/rails.vim#L32-L34
function! s:gsub(str,pat,rep)
  return substitute(a:str,'\v\C'.a:pat,a:rep,'g')
endfunction

" }}}1
" Completion Functions {{{1

" Completion function for Ember types and, if the prompt already contains the
" type, the file names associated with that type
function! ember#complete_class_and_file(ArgLead, CmdLine, CursorPos)
  let types = ember#get_blueprints()
  let type = get(split(a:CmdLine, ' '), 1, '')
  if index(types, type) >= 0
    let files = s:get_files_for_type(type)
    return s:completion_filter(files, a:ArgLead)
  endif
  return s:completion_filter(types, a:ArgLead)
endfunction

function! ember#HandlebarsComplete(findstart, base)
  if s:equal(a:findstart, 1)
    return a:findstart
  else
    let matches = []
    let components = s:get_files_for_type('component')
    for component in components
      if component =~ a:base
        let matches += [{'word': component, 'kind': 'component'}]
      endif
    endfor
    let helpers = s:get_files_for_type('helper')
    for helper in helpers
      if helper =~ a:base
        let matches += [{'word': helper, 'kind': 'helper'}]
      endif
    endfor
    return {'words': matches, 'refresh': 'always'}
  endif
endfunction

" }}}1
" Helper Functions {{{1

function! ember#detect_cli_project(...)
  if exists('g:ember_root')
    return 1
  endif
  let file = findfile('.ember-cli', '.;')
  if !empty(file) && isdirectory(fnamemodify(file, ':p:h') . '/app')
    let g:ember_root = fnamemodify(file, ':p:h')
    call ember#config_vim()
    return 1
  endif
endfunction

function! ember#config_vim()
  if g:ember_config_vim && g:ember_config_vim_suffixesadd
    set suffixesadd+=.js
  endif
endfunction

" Returns the module name for a given test file
" Returns an empty string if no match was found
function! ember#get_module_name()
  let currentLineNumber = 1
  let maxLineNumber = line('$')
  let moduleNameNotFound = 1

  while moduleNameNotFound && maxLineNumber >= currentLineNumber
    let line = getline(currentLineNumber)
    if s:startswith(line, 'module')
      let moduleNameNotFound = 0
      let type = s:get_module_type(line)
      if s:equal(type, 'module')
        let moduleName = s:get_module_name_for_acceptance(line)
      else
        let moduleName = s:get_module_name_for_unit(line, type)
      endif
      return moduleName
    else
      let currentLineNumber = currentLineNumber + 1
    endif
  endwhile
  return ''
endfunction

function! s:get_module_type(line)
  let indexOfParen = strridx(a:line, '(')
  let moduleDec = a:line[0 : indexOfParen - 1]
  return moduleDec
endfunction

" Get Module Names from Line {{{2
function! s:get_module_name_for_unit(line, type)
  let moduleName = matchstr(a:line, '\([''"]\)\(.\{-}\)\1', 0, 3)
  if s:equal(moduleName, '')
    let moduleName = matchstr(a:line, '\([''"]\)\(.\{-}\)\1', 0, 1)
    if s:equal(a:type, 'moduleForComponent')
      " If the test is for a component, add 'component:' before the read name
      " Also strip off the quotes and add our own, so that we don't end up with
      " mis-matched quotation
      let moduleName = "'component:" . moduleName[1 : len(moduleName) - 2] . "'"
    endif
    if s:equal(a:type, 'moduleForModel')
      " Ditto, but for models
      let moduleName = "'model:" . moduleName[1 : len(moduleName) - 2] . "'"
    endif
  endif
  return moduleName
endfunction

function! s:get_module_name_for_acceptance(line)
  return matchstr(a:line, '\([''"]\)\(.\{-}\)\1', 0, 1)
endfunction
" }}}2

" }}}1
" User Functions {{{1

function! ember#Generate(type, name)
  call s:makeAndSwitch('ember generate', a:type, a:name)
endfunction

function! ember#Destroy(type, name)
  call s:makeAndSwitch('ember destroy', a:type, a:name)
endfunction

function! ember#Test(bang, ...)
  if a:bang
    call s:makeAndSwitch('ember test --serve')
  else
    call s:makeAndSwitch('ember test')
  endif
endfunction

" Test only the module in the current file
function! ember#TestModule()
  let currentPath = expand('%:p')
  if currentPath =~ g:ember_root . '/tests/'
    let moduleName = ember#get_module_name()
    if moduleName ==? ''
      " Can we infer the module name from the file name?
      echom 'Could not find module name; make sure it is set'
    else
      call s:makeAndSwitchTests("ember test --module ", moduleName)
    endif
  else
    echom 'Current buffer is not an Ember test'
  endif
endfunction

function! ember#Server(...)
  if len(a:000)
    call s:makeAndSwitch('ember server', join(a:000, ' '))
  else
    call s:makeAndSwitch('ember server')
  endif
endfunction

function! ember#Build(...)
  if len(a:000)
    call s:makeAndSwitch('ember build', join(a:000, ' '))
  else
    call s:makeAndSwitch('ember build')
  endif
endfunction

function! ember#InstallAddon(name)
  call s:makeAndSwitch('ember install', a:name)
endfunction

function! ember#NpmInstall(...)
  call s:makeAndSwitch('npm install')
endfunction
" }}}1

