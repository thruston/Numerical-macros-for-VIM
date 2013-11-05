#! /usr/bin/env python
# TeX-aware inline calculator/expression evaluator for Vim
# uses code in lumberjack.py
# Toby Thurston -- 05 Nov 2013 

import vim
import lumberjack
import sys

line = vim.current.line
(row,col) = vim.current.window.cursor

(prefix, expression, suffix) = lumberjack.find_expression(line,col)
answer = lumberjack.evaluate_expression(expression)
vim.current.line = prefix+answer+suffix
vim.current.window.cursor = (row,len(prefix+answer)) 

# Normal 2+2 
