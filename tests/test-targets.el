;;; Setup
(require 'targets)

(targets-setup t)

(defmacro targets-with (in &rest body)
  "This is `lispy-with' modified for targets.
Note that | is considered to be \"on\" a character, meaning that it is included
in a visual selection. ~ on the other hand is not considered to be on a
character, so when it represents the region end, the character after it is not
considered as part of the region."
  (declare (indent 1))
  `(let ((temp-buffer (generate-new-buffer " *temp*")))
     (save-window-excursion
       (unwind-protect
           (progn
             (switch-to-buffer temp-buffer)
             (emacs-lisp-mode)
             (transient-mark-mode 1)
             (evil-mode)
             (insert ,in)
             (goto-char (point-min))
             (when (search-forward "~" nil t)
               (backward-delete-char 1)
               (set-mark (point)))
             (goto-char (point-max))
             (search-backward "|")
             (delete-char 1)
             (setq current-prefix-arg nil)
             ,@(mapcar (lambda (x)
                         (if (or (stringp x)
                                 (and (listp x)
                                      (eq (car x) 'kbd)))
                             `(evil-execute-macro 1 ,x)
                           x))
                       body)
             (insert "|")
             (when (region-active-p)
               (exchange-point-and-mark)
               ;; because not considering ~ as "on" like |
               (when (= (point) (region-end))
                 (forward-char))
               (insert "~"))
             (buffer-substring-no-properties
              (point-min)
              (point-max)))
         (and (buffer-name temp-buffer)
              (kill-buffer temp-buffer))))))

;;; Pair Tests
;; TODO tests for regexp pair
(describe "The targets pair text object"
  :before-all (setq evil-move-cursor-back nil)
  (describe "targets-inner-paren"
    (it "should delete the contents of parens"
      (expect (targets-with "(a |b c)" "di(")
              :to-equal "(|)"))
    (it "should select the contents of parens"
      (expect (targets-with "(a |b c)" "vi(")
              :to-equal "(~a b |c)"))
    (it "should, by default, seek forward"
      (expect (targets-with "|a (b c d)" "di(")
              :to-equal "a (|)"))
    (it "should, by default, seek forward then backward"
      (expect (targets-with "(a b c) |d" "di(")
              :to-equal "(|) d"))
    (it "should seek forward in visual state as well"
      (expect (targets-with "|a (b c d)" "vi(")
              :to-equal "a (~b c |d)"))
    (it "should seek backward in visual state as well"
      (expect (targets-with "(a b c) |d" "vi(")
              :to-equal "(~a b |c) d"))
    (it "should grow an existing selection"
      (expect (targets-with "((~a b |c))" "i(")
              :to-equal "(~(a b c|))"))
    (it "should support a count"
      (expect (targets-with "((a b |c))" "d2i(")
              :to-equal "(|)"))
    (it "should support a count in visual state as well"
      (expect (targets-with "((a b |c))" "v2i(")
              :to-equal "(~(a b c|))")))
  (describe "targets-a-paren"
    (it "should delete the parens and their contents"
      (expect (targets-with "(a |b c)" "da(")
              :to-equal "|"))
    (it "should select the parens and their contents"
      (expect (targets-with "(a |b c)" "va(")
              :to-equal "~(a b c|)"))
    (it "should, by default, seek forward"
      (expect (targets-with "|a (b c d)" "da(")
              :to-equal "a |"))
    (it "should, by default, seek forward then backward"
      (expect (targets-with "(a b c) |d" "da(")
              :to-equal "| d"))
    (it "should seek forward in visual state as well"
      (expect (targets-with "|a (b c d)" "va(")
              :to-equal "a ~(b c d|)"))
    (it "should seek backward in visual state as well"
      (expect (targets-with "(a b c) |d" "va(")
              :to-equal "~(a b c|) d"))
    (it "should grow an existing selection"
      (expect (targets-with "(~(a b c)|)" "a(")
              :to-equal "~((a b c)|)"))
    (it "should support a count"
      (expect (targets-with "((a b |c))" "d2a(")
              :to-equal "|"))
    (it "should support a count in visual state as well"
      (expect (targets-with "((a b |c))" "v2a(")
              :to-equal "~((a b c)|)")))
  (describe "targets-inside-paren"
    (it "should delete the contents of parens excluding whitespace"
      (expect (targets-with "( a |b c )" "dI(")
              :to-equal "( | )"))
    (it "should select the contents of parens excluding whitespace"
      (expect (targets-with "( a |b c )" "vI(")
              :to-equal "( ~a b |c )"))
    (it "should, by default, seek forward"
      (expect (targets-with "|a ( b c d )" "dI(")
              :to-equal "a ( | )"))
    (it "should, by default, seek forward then backward"
      (expect (targets-with "( a b c ) |d" "dI(")
              :to-equal "( | ) d"))
    (it "should seek forward in visual state as well"
      (expect (targets-with "|a ( b c d )" "vI(")
              :to-equal "a ( ~b c |d )"))
    (it "should seek backward in visual state as well"
      (expect (targets-with "( a b c ) |d" "vI(")
              :to-equal "( ~a b |c ) d"))
    (xit "should grow an existing selection"
      (expect (targets-with "( ( ~a b c| ) )" "I(")
              :to-equal "( ~( a b c |) )"))
    (it "should support a count"
      (expect (targets-with "( ( a b |c ) )" "d2I(")
              :to-equal "( | )"))
    (it "should support a count in visual state as well"
      (expect (targets-with "( ( a b |c ) )" "v2I(")
              :to-equal "( ~( a b c |) )")))
  (describe "targets-around-paren"
    (it "should delete the parens, their contents, and trailing whitespace"
      (expect (targets-with " (a |b c) " "dA(")
              :to-equal " |"))
    (it "should delete the parens, their contents, and leading whitespace"
      (expect (targets-with " (a |b c)" "dA(")
              :to-equal "|"))
    (it "should select the parens, their contents, and trailing whitespace"
      (expect (targets-with " (a |b c) " "vA(")
              :to-equal " ~(a b c)| "))
    (it "should select the parens, their contents, and leading whitespace"
      (expect (targets-with " (a |b c)" "vA(")
              :to-equal "~ (a b c|)"))
    (it "should, by default, seek forward"
      (expect (targets-with "|a (b c d) " "dA(")
              :to-equal "a |"))
    (it "should, by default, seek forward then backward"
      (expect (targets-with " (a b c) |d" "dA(")
              :to-equal " |d"))
    (it "should seek forward in visual state as well"
      (expect (targets-with "|a (b c d) " "vA(")
              :to-equal "a ~(b c d)| "))
    (it "should seek backward in visual state as well"
      (expect (targets-with " (a b c) |d" "vA(")
              :to-equal " ~(a b c)| d"))
    (it "should grow an existing selection"
      (expect (targets-with "(~(a b c) |) d" "A(")
              :to-equal "~((a b c) )| d"))
    (it "should support a count"
      (expect (targets-with "((a |b c) ) d" "d2A(")
              :to-equal "|d"))
    (it "should support a count in visual state as well"
      (expect (targets-with "((a |b c) ) d" "v2A(")
              :to-equal "~((a b c) )| d")))
  (describe "targets-inner-next-paren"
    (it "should delete the contents of the next parens"
      (expect (targets-with "|a (b c d)" "din(")
              :to-equal "|a ()"))
    (it "should select the contents of the next parens"
      (expect (targets-with "|a (b c d)" "vin(")
              :to-equal "a (~b c |d)"))
    (it "should support a count"
      (expect (targets-with "|a (b c d) (e f g)" "d2in(")
              :to-equal "|a (b c d) ()"))
    (it "should support a count in visual state as well"
      (expect (targets-with "|a (b c d) (e f g)" "v2in(")
              :to-equal "a (b c d) (~e f |g)"))
    (it "should support a count in nested parens"
      (expect (targets-with "|a (b (c d) e)" "d2in(")
              :to-equal "|a (b () e)"))
    (it "should support a count in nested parens in visual state as well"
      (expect (targets-with "|a (b (c d) e)" "v2in(")
              :to-equal "a (b (~c |d) e)")))
  (describe "targets-inner-last-paren"
    ;; TODO post-command-hook not being run so test result incorrect
    (xit "should delete the contents of the last parens"
      (expect (targets-with "(a b c) |d" "dil(")
              :to-equal "() |d")
      (expect (targets-with "(a (b |c))" "dil(")
              :to-equal "(|)"))
    (it "should select the contents of the last parens"
      (expect (targets-with "(a b c) |d" "vil(")
              :to-equal "(~a b |c) d")
      (expect (targets-with "(a (b |c))" "vil(")
              :to-equal "(~a (b c|))")
      (expect (targets-with "((a (b c)) (d |e))" "vil(")
              :to-equal "((~a (b c|)) (d e))"))
    (xit "should support a count"
      (expect (targets-with "(a b c) (d e f) |g" "d2il(")
              :to-equal "() (d e f) |g")
      (expect (targets-with "((a (b c)) (d |e))" "d2il(")
              :to-equal "((a ()) (d |e))"))
    (it "should support a count in visual state as well"
      (expect (targets-with "(a b c) (d e f) |g" "v2il(")
              :to-equal "(~a b |c) (d e f) g")
      (expect (targets-with "((a (b c)) (d |e))" "v2il(")
              :to-equal "((a (~b |c)) (d e))"))
    (xit "should support a count in nested parens"
      (expect (targets-with "(a (b c) d) |e" "d2il(")
              :to-equal "(a () d) |e"))
    (it "should support a count in nested parens in visual state as well"
      (expect (targets-with "(a (b c) d) |e" "v2il(")
              :to-equal "(a (~b |c) d) e"))))

;;; Quote Tests
(describe "The targets quote text object"
  :before-all (setq evil-move-cursor-back nil)
  (describe "targets-inner-double-quote"
    (it "should delete the contents of quotes"
      (expect (targets-with "\"a |b c\"" "di\"")
              :to-equal "\"|\""))
    (it "should select the contents of quotes"
      (expect (targets-with "\"a |b c\"" "vi\"")
              :to-equal "\"~a b |c\""))
    (it "should, by default, seek forward to the next proper quote"
      (expect (targets-with "\"a b c\" |d \"e f g\"" "di\"")
              :to-equal "\"a b c\" d \"|\""))
    (it "should, by default, seek forward then backward"
      (expect (targets-with "\"a b c\" |d" "di\"")
              :to-equal "\"|\" d"))
    (it "should seek forward in visual state as well"
      (expect (targets-with "|a \"b c d\"" "vi\"")
              :to-equal "a \"~b c |d\""))
    (it "should seek backward in visual state as well"
      (expect (targets-with "\"a b c\" |d" "vi\"")
              :to-equal "\"~a b |c\" d")))
  (describe "targets-a-double-quote"
    (it "should delete the quotes and their contents but no outer whitespace"
      (expect (targets-with "\"a |b c\" d" "da\"")
              :to-equal "| d"))
    (it "should select the quotes and their contents but no outer whitespace"
      (expect (targets-with "\"a |b c\" d" "va\"")
              :to-equal "~\"a b c|\" d")))
  (describe "targets-inside-double-quote"
    (it "should delete the contents of quotes excluding whitespace"
      (expect (targets-with "\" a |b c \"" "dI\"")
              :to-equal "\" | \""))
    (it "should select the contents of quotes excluding whitespace"
      (expect (targets-with "\" a |b c \"" "vI\"")
              :to-equal "\" ~a b |c \"")))
  (describe "targets-around-double-quotes"
    (it "should delete the quotes, their contents, and trailing whitespace"
      (expect (targets-with " \"a |b c\" " "dA\"")
              :to-equal " |"))
    (it "should delete the quotes, their contents, and leading whitespace"
      (expect (targets-with " \"a |b c\"" "dA\"")
              :to-equal "|"))
    (it "should select the quotes, their contents, and trailing whitespace"
      (expect (targets-with " \"a |b c\" " "vA\"")
              :to-equal " ~\"a b c\"| "))
    (it "should select the quotes, their contents, and leading whitespace"
      (expect (targets-with " \"a |b c\"" "vA\"")
              :to-equal "~ \"a b c|\"")))
  (describe "targets-inner-next-double-quote"
    (xit "should delete the contents of the next proper quote"
      (expect (targets-with "\"a |b c\" d \"e f g\"" "din\"")
              :to-equal "\"a |b c\" d \"\""))
    (it "should select the contents of the next proper quote"
      (expect (targets-with "\"a |b c\" d \"e f g\"" "vin\"")
              :to-equal "\"a b c\" d \"~e f |g\""))
    ;; TODO same post-command-hook problem
    (xit "should support a count"
      (expect (targets-with "|a \"b c d\" \"e f g\"" "d2in\"")
              :to-equal "|a \"b c d\" \"\""))
    (it "should support a count in visual state as well"
      (expect (targets-with "|a \"b c d\" \"e f g\"" "v2in\"")
              :to-equal "a \"b c d\" \"~e f |g\"")))
  (describe "targets-inner-last-double-quote"
    (xit "should delete the contents of the last proper quote"
      (expect (targets-with "\"a b c\" d \"e |f g\"" "dil\"")
              :to-equal "\"\" d \"e |f g\""))
    (it "should select the contents of the last proper quote"
      (expect (targets-with "\"a b c\" d \"e |f g\"" "vil\"")
              :to-equal "\"~a b |c\" d \"e f g\""))
    (it "should work when directly after a quote"
      (expect (targets-with "\"a b c\" \"d e f\"|" "vil\"")
              :to-equal "\"a b c\" \"~d e |f\""))
    (xit "should support a count"
      (expect (targets-with "\"a b c\" \"d e f\" |g" "d2il\"")
              :to-equal "\"\" \"d e f\" |g"))
    (it "should support a count in visual state as well"
      (expect (targets-with "\"a b c\" \"d e f\" |g" "v2il\"")
              :to-equal "\"~a b |c\" \"d e f\" g"))))

;;; Separator Tests
(describe "The targets separator text object"
  :before-all (setq evil-move-cursor-back nil)
  (describe "targets-inner-comma"
    (it "should delete the contents of commas"
      (expect (targets-with ", a |b c," "di,")
              :to-equal ",|,"))
    (it "should select the contents of commas"
      (expect (targets-with ", a |b c," "vi,")
              :to-equal ",~ a b |c,"))
    (it "should, by default, seek forward"
      (expect (targets-with "|a b c, d e f," "di,")
              :to-equal "a b c,|,"))
    (it "should, by default, seek forward then backward"
      (expect (targets-with ", a b c, |d" "di,")
              :to-equal ",|, d"))
    (it "should seek forward in visual state as well"
      (expect (targets-with "|a, b c d," "vi,")
              :to-equal "a,~ b c |d,"))
    (it "should seek backward in visual state as well"
      (expect (targets-with ", a b c, |d" "vi,")
              :to-equal ",~ a b |c, d")))
  (describe "targets-a-comma"
    (it "should delete the contents of commas and the first comma"
      (expect (targets-with ", a |b c, d" "da,")
              :to-equal "|, d"))
    (it "should select the contents of commas and the first comma"
      (expect (targets-with ", a |b c, d" "va,")
              :to-equal "~, a b |c, d")))
  (describe "targets-inside-double-quote"
    (it "should delete the contents of commas excluding whitespace"
      (expect (targets-with ", a |b c ," "dI,")
              :to-equal ", | ,"))
    (it "should select the contents of commas excluding whitespace"
      (expect (targets-with ", a |b c ," "vI,")
              :to-equal ", ~a b |c ,")))
  (describe "targets-around-comma"
    (it "should delete the commas, their contents, and trailing whitespace"
      (expect (targets-with " , a |b c, " "dA,")
              :to-equal " |"))
    (it "should delete the commas, their contents, and leading whitespace"
      (expect (targets-with " , a |b c," "dA,")
              :to-equal "|"))
    (it "should select the commas, their contents, and trailing whitespace"
      (expect (targets-with " , a |b c, " "vA,")
              :to-equal " ~, a b c,| "))
    (it "should select the commas, their contents, and leading whitespace"
      (expect (targets-with " , a |b c," "vA,")
              :to-equal "~ , a b c|,")))
  (describe "targets-inner-next-comma"
    (xit "should delete the contents of the next commas"
      (expect (targets-with ", a |b c, d e f," "din,")
              :to-equal " ,a |b c,,"))
    (it "should select the contents of the next commas"
      (expect (targets-with ", a |b c, d e f," "vin,")
              :to-equal ", a b c,~ d e |f,"))
    (xit "should support a count"
      (expect (targets-with "|a, b c d, e f g," "d2in,")
              :to-equal "|a, b c d,,"))
    (it "should support a count in visual state as well"
      (expect (targets-with "|a, b c d, e f g," "v2in,")
              :to-equal "a, b c d,~ e f |g,")))
  (describe "targets-inner-last-comma"
    (xit "should delete the contents of the last commas"
      (expect (targets-with ", a b c, d |e f," "dil,")
              :to-equal ",, d |e f,"))
    (it "should select the contents of the last commas"
      (expect (targets-with ", a b c, d |e f," "vil,")
              :to-equal ",~ a b |c, d e f,"))
    (it "should work when directly after a comma"
      (expect (targets-with ", a b c, d e f,|" "vil,")
              :to-equal ", a b c,~ d e |f,"))
    (xit "should support a count"
      (expect (targets-with ", a b c, d e f, |g" "d2il,")
              :to-equal ",, d e f, |g"))
    (it "should support a count in visual state as well"
      (expect (targets-with ", a b c, d e f, |g" "v2il,")
              :to-equal ",~ a b |c, d e f, g"))))

;;; Object/Thing Tests
(describe "The targets object/thing text object"
  :before-all (setq evil-move-cursor-back nil)
  (describe "targets-inner-word"
    (it "should delete a word excluding whitespace"
      (expect (targets-with "one |two three" "diw")
              :to-equal "one | three"))
    (it "should select a word excluding whitespace"
      (expect (targets-with "one |two three" "viw")
              :to-equal "one ~tw|o three"))
    (it "should grow an existing selection"
      (expect (targets-with "~one| two three" "iw")
              :to-equal "~one tw|o three"))
    (it "should support a count"
      (expect (targets-with "|one two three" "d3iw")
              :to-equal "| three")
      (expect (targets-with "|one two three" "v3iw")
              :to-equal "~one tw|o three")))
  (describe "targets-a-word"
    (it "should delete a word and trailing or leading whitespace"
      (expect (targets-with "one |two three" "daw")
              :to-equal "one |three")
      (expect (targets-with "one |two" "daw")
              :to-equal "one|"))
    (it "should select a word and trailing or leading whitespace"
      (expect (targets-with "one |two three" "vaw")
              :to-equal "one ~two| three")
      (expect (targets-with "one |two" "vaw")
              :to-equal "one~ tw|o"))
    (it "should grow an existing selection"
      (expect (targets-with "~one| two three" "aw")
              :to-equal "~one two| three"))
    (it "should support a count"
      (expect (targets-with "|one two three" "d2aw")
              :to-equal "|three")
      (expect (targets-with "|one two three" "v2aw")
              :to-equal "~one two| three")))
  (describe "targets-inner-next-word"
    (xit "should delete the next word excluding whitespace"
      (expect (targets-with "|one two three" "dinw")
              :to-equal "|one  three"))
    (it "should select the next word excluding whitespace"
      (expect (targets-with "|one two three" "vinw")
              :to-equal "one ~tw|o three"))
    (it "should support a count"
      ;; (expect (targets-with "|one two three" "d2inw")
      ;;         :to-equal "|one two ")
      (expect (targets-with "|one two three" "v2inw")
              :to-equal "one two ~thre|e")))
  (describe "targets-inner-last-word"
    (xit "should delete the last word excluding whitespace"
      (expect (targets-with "one two |three" "dilw")
              :to-equal "one  |three"))
    (it "should select the last word excluding whitespace"
      (expect (targets-with "one two |three" "vilw")
              :to-equal "one ~tw|o three"))
    (it "should support a count"
      ;; (expect (targets-with "one two |three" "d2ilw")
      ;;         :to-equal " two |three")
      (expect (targets-with "one two |three" "v2ilw")
              :to-equal "~on|e two three"))))
