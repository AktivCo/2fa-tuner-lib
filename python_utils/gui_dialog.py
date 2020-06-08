from tkinter import messagebox
from tkinter import simpledialog

def yesno(title, text):
    return messagebox.askquestion (title, text)

def show_msg(title, text):
    messagebox.showinfo(title, text)

def get_pass(title, text):
    return simpledialog.askstring(title, text, show='*')

show_msg("kek", "lol")
get_pass("kek", "lol")
answer = yesno("kek", "lol")
if answer == "yes":
    exit(1)
else:
    exit(0)
