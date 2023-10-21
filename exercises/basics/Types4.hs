module Types4 where

{-
- You can combine multiple values of the SAME type in a *List*.

- You can define a list with a comma separated list of values within *brackets*.

- It's type signature has the type of the elements within brackets.

- A list can have any number of elements, even 0.
-}

list1 :: [Int]
list1 = [1, 2, 3, 4]

emptyList :: [Float]
emptyList = []

boolList :: [Bool]
boolList = [True]

ints :: [Int]
ints = [1, -2]

floatingVals :: [Float]
floatingVals = [2.3, 3.5, 8.5, 10.1, 13.3, -42.1]

characters :: [Char]
characters = ['f', 'e']

unsignedInts :: [Word]
unsignedInts = [1, 2, 3]

mixedList :: [Float]
mixedList = [2, 3, 5, 6.7]
