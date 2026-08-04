# This script generates a random password based on user-defined criteria.
# It allows the user to specify the length of the password and the types of symbols and numbers to include.

# Importing the random module to generate random choices
import random

# Defining the character sets for letters, numbers, and symbols
letters = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l',
            'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
            'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L',
            'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z']
numbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']
symbols = ['!', '#', '$', '%', '&', '(', ')', '*', '+']

# Welcoming the user to the password generator
print("Welcome to the Password Generator!")

# Prompting the user for the number of letters, symbols, and numbers they want in their password
nr_letters = int(input("How many letters would you like in your password?\n"))
nr_symbols = int(input(f"How many symbols would you like?\n"))
nr_numbers = int(input(f"How many numbers would you like?\n"))

# define password_list to store the generated password characters
password_list = []

# Generating random letters, symbols, and numbers based on user input
password_letters = [random.choice(letters) for i in range(nr_letters)]
password_symbols = [random.choice(symbols) for i in range(nr_symbols)]  
password_numbers = [random.choice(numbers) for i in range(nr_numbers)]  

# Combining the generated characters into a single list 
password_list.extend(password_letters)
password_list.extend(password_symbols) 
password_list.extend(password_numbers)

# Shuffling the password list to ensure randomness
random.shuffle(password_list)

print("Your password is: ")
# Joining the list into a string to form the final password
password = "".join(password_list)
print(password)