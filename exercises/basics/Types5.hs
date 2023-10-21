module Types5 where

{-
- A "String" is actually the same as a "list of characters".

- We can define such an expression using either double quotes,
  or by creating a bracketed list of characters. The former is
  usually easier.
-}

charList :: [Char]
charList = "This is strange"

aString :: String
aString = ['H', 'e', 'l', 'l', 'o']

charList2 :: String
charList2 = "Hey"

string2 :: [Char]
string2 = ['H', 'o', 'w']
