module Types3 where

{-
- We can combine values of different types together using *tuples*.

- A tuple consists of 2 or more comma-separated values within parentheses.

- The type signature similarly has each individual type within parens.
-}

tuple1 :: (Int, Int)
tuple1 = (5, -2)

tuple2 :: (Char, Bool, Double)
tuple2 = ('a', True, 9.563)

tuple3 :: (Word, Word, Bool, Bool)
tuple3 = (3, 3, True, False)

tuple4 :: (String, String, String)
tuple4 = ("hello", "word", 'f' : 'e' : 'l' : 'i': [])

tuple5 :: (Int, String, Int, String, Double)
tuple5 = (1, "one", 0x1, "uno", 1.0)
