# ----------------------------------------------------------------------------------------------------------------# 
# Program: Miles to Kilometer Converter
# Description: Simple Tkinter GUI app that converts miles to kilometers
# ----------------------------------------------------------------------------------------------------------------#

# ----------------------------------------------------------------------------------------------------------------#
# Imports
# ----------------------------------------------------------------------------------------------------------------#
from tkinter import *   # Import all Tkinter classes/functions

# ----------------------------------------------------------------------------------------------------------------#
# Functions
# ----------------------------------------------------------------------------------------------------------------#

def miles_to_km():
    """
    Convert miles entered by the user into kilometers and update the result label.
    """
    miles = float(miles_input.get())                   # Get user input and convert to float
    km = round(miles * 1.609, ndigits=4)               # Perform conversion and round result
    kilometer_result_label.config(text=f"{km}")        # Update label with result

# ----------------------------------------------------------------------------------------------------------------#
# Window Setup
# ----------------------------------------------------------------------------------------------------------------#
window = Tk()                                 # Create the main application window
window.title("Miles to Kilometer Converter")  # Set window title
window.config(padx=20, pady=20)               # Add padding around the window content

# ----------------------------------------------------------------------------------------------------------------#
# Input Section
# ----------------------------------------------------------------------------------------------------------------#
miles_input = Entry(width=7)           # Entry widget for user to type miles
miles_input.grid(row=0, column=1)      # Place entry in grid at row 0, column 1

miles_label = Label(text="Miles")      # Label next to entry
miles_label.grid(row=0, column=2)      # Place label in grid at row 0, column 2

# ----------------------------------------------------------------------------------------------------------------#
# Result Section
# ----------------------------------------------------------------------------------------------------------------#
is_egual_label = Label(text="is equal to")   # Static text label
is_egual_label.grid(row=1, column=0)         # Place label at row 1, column 0

kilometer_result_label = Label(text="0")     # Label to show conversion result
kilometer_result_label.grid(row=1, column=1) # Place result label at row 1, column 1

kilometer_label = Label(text="Km")           # Label for unit (kilometers)
kilometer_label.grid(row=1, column=2)        # Place label at row 1, column 2

# ----------------------------------------------------------------------------------------------------------------#
# Button Section
# ----------------------------------------------------------------------------------------------------------------#
calculate_button = Button(text="calculate", command=miles_to_km)  # Button to trigger conversion function
calculate_button.grid(row=2, column=1)       # Place button at row 2, column 1

# ----------------------------------------------------------------------------------------------------------------#
# Main Loop
# ----------------------------------------------------------------------------------------------------------------#
window.mainloop()                    # Keep window open and wait for user interaction
