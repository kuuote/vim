" Test for :global and :vglobal

func Test_yank_put_clipboard()
  new
  call setline(1, ['a', 'b', 'c'])
  set clipboard=unnamed
  g/^/normal yyp
  call assert_equal(['a', 'a', 'b', 'b', 'c', 'c'], getline(1, 6))
  set clipboard=unnamed,unnamedplus
  call setline(1, ['a', 'b', 'c'])
  g/^/normal yyp
  call assert_equal(['a', 'a', 'b', 'b', 'c', 'c'], getline(1, 6))
  set clipboard&
  bwipe!
endfunc

func Test_global_set_clipboard()
  CheckFeature clipboard_working
  new
  set clipboard=unnamedplus
  let @+='clipboard' | g/^/set cb= | let @" = 'unnamed' | put
  call assert_equal(['','unnamed'], getline(1, '$'))
  set clipboard&
  bwipe!
endfunc

func Test_nested_global()
  new
  call setline(1, ['nothing', 'found', 'found bad', 'bad'])
  call assert_fails('g/found/3v/bad/s/^/++/', 'E147:')
  g/found/v/bad/s/^/++/
  call assert_equal(['nothing', '++found', 'found bad', 'bad'], getline(1, 4))
  bwipe!
endfunc

func Test_global_error()
  call assert_fails('g\\a', 'E10:')
  call assert_fails('g', 'E148:')
  call assert_fails('g/\(/y', 'E54:')
endfunc

" Test for printing lines using :g with different search patterns
func Test_global_print()
  new
  call setline(1, ['foo', 'bar', 'foo', 'foo'])
  let @/ = 'foo'
  let t = execute("g/")->trim()->split("\n")
  call assert_equal(['foo', 'foo', 'foo'], t)

  " Test for Vi compatible patterns
  let @/ = 'bar'
  let t = execute('g\/')->trim()->split("\n")
  call assert_equal(['bar'], t)

  normal gg
  s/foo/foo/
  let t = execute('g\&')->trim()->split("\n")
  call assert_equal(['foo', 'foo', 'foo'], t)

  let @/ = 'bar'
  let t = execute('g?')->trim()->split("\n")
  call assert_equal(['bar'], t)

  " Test for the 'Pattern found in every line' message
  let v:statusmsg = ''
  v/foo\|bar/p
  call assert_notequal('', v:statusmsg)

  " In Vim9 script this is an error
  let caught = 'no'
  try
    vim9cmd v/foo\|bar/p
  catch /E538/
    let caught = 'yes'
    call assert_match('E538: Pattern found in every line: foo\|bar', v:exception)
  endtry
  call assert_equal('yes', caught)

  " In Vim9 script not matching is an error
  let caught = 'no'
  try
    vim9cmd g/foobarnotfound/p
  catch /E486/
    let caught = 'yes'
    call assert_match('E486: Pattern not found: foobarnotfound', v:exception)
  endtry
  call assert_equal('yes', caught)

  close!
endfunc

func Test_global_empty_pattern()
  " populate history
  silent g/hello/

  redir @a
  g//
  redir END

  call assert_match('Pattern not found: hello', @a)
  "                                     ^~~~~ this was previously empty
endfunc

" Test for global command with newline character
func Test_global_newline()
  new
  call setline(1, ['foo'])
  exe "g/foo/s/f/h/\<NL>s/o$/w/"
  call assert_equal('how', getline(1))
  call setline(1, ["foo\<NL>bar"])
  exe "g/foo/s/foo\\\<NL>bar/xyz/"
  call assert_equal('xyz', getline(1))
  close!
endfunc

" Test :g with ? as delimiter.
func Test_global_question_delimiter()
  new
  call setline(1, ['aaaaa', 'b?bbb', 'ccccc', 'ddd?d', 'eeeee'])
  g?\??delete
  call assert_equal(['aaaaa', 'ccccc', 'eeeee'], getline(1, '$'))
  bwipe!
endfunc

func Test_global_wrong_delimiter()
  call assert_fails('g x^bxd', 'E146:')
endfunc

" Test for interrupting :global using Ctrl-C
func Test_interrupt_global()
  CheckRunVimInTerminal

  let lines =<< trim END
    cnoremap ; <Cmd>sleep 10<CR>
    call setline(1, repeat(['foo'], 5))
  END
  call writefile(lines, 'Xtest_interrupt_global', 'D')
  let buf = RunVimInTerminal('-S Xtest_interrupt_global', {'rows': 6})

  call term_sendkeys(buf, ":g/foo/norm :\<C-V>;\<CR>")
  " Wait for :sleep to start
  call TermWait(buf, 100)
  call term_sendkeys(buf, "\<C-C>")
  call WaitForAssert({-> assert_match('Interrupted', term_getline(buf, 6))}, 1000)

  " Also test in Ex mode
  call term_sendkeys(buf, "gQg/foo/norm :\<C-V>;\<CR>")
  " Wait for :sleep to start
  call TermWait(buf, 100)
  call term_sendkeys(buf, "\<C-C>")
  call WaitForAssert({-> assert_match('Interrupted', term_getline(buf, 5))}, 1000)

  call StopVimInTerminal(buf)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
