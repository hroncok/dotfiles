if &cp || exists('g:loaded_session')
	finish
endif

let g:loaded_session = 1

function! s:session_filename()
	let l:session_dir = expand("~/.vim/session/")
	if !isdirectory(l:session_dir)
		call mkdir(l:session_dir, "p")
	endif
	return l:session_dir . fnamemodify(".", ":p:gs%[^A-Za-z0-9]%_%")
endfunc

function! s:load_session()
	let l:session = s:session_filename()
	if file_readable(l:session)
		execute "source" fnameescape(l:session)
	endif
endfunc

function! s:save_session()
	if len(v:this_session)
		execute "mksession!" fnameescape(v:this_session)
	endif
endfunc

function! s:new_session()
	let v:this_session = s:session_filename()
	call s:save_session()
endfunc

function! s:rm_session()
	if len(v:this_session)
		call delete(v:this_session)
		let v:this_session = ""
	endif
endfunc

command! LoadSession call s:load_session()
command! NewSession call s:new_session()
command! RmSession call s:rm_session()

augroup MySession
	au!
	autocmd VimLeave * call s:save_session()
augroup END
