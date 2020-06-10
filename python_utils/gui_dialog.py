from tkinter import messagebox
from tkinter import simpledialog
from tkinter import ttk
import tkinter as tk

import argparse
from sys import argv, stdin

def center(win):
    win.update_idletasks()
    width = win.winfo_width()
    height = win.winfo_height()
    x = (win.winfo_screenwidth() // 2) - (width // 2)
    y = (win.winfo_screenheight() // 2) - (height // 2)
    win.geometry('{}x{}+{}+{}'.format(width, height, x, y))

def yesno(title, text):
    tk.Tk().withdraw()
    return messagebox.askquestion (title, text)

def show_msg(title, text):
    tk.Tk().withdraw()
    messagebox.showinfo(title, text)
    root.mainloop()

def get_pass(title, text):
    root = tk.Tk()
    passwordtext = tk.Label(root, text=text)
    passwordguess = tk.Entry(root, show="*") 
    
    buttonFrame= tk.Frame(root)
    cancelButton = tk.Button(buttonFrame, text="Cancel", command= lambda: exit(255))

    def okButtonClicked(event):    
        print(passwordguess.get())
        exit(0)

    okButton = tk.Button(buttonFrame, text="OK", command= okButtonClicked)
    root.bind('<Return>', okButtonClicked)

    passwordtext.pack()
    passwordguess.pack(fill='both', expand=1, padx=10)
    cancelButton.pack(side=tk.LEFT, padx=10, pady=10)
    okButton.pack(side=tk.RIGHT, padx=10, pady=10)
    buttonFrame.pack(fill='both', expand=1)
    center(root)
    root.mainloop()
    exit(255)

def show_list(title, columns):
    root = tk.Tk()
    root.title(title)
    rows=[]

    for line in stdin:
        rows.append(line[:-1].split("\t"))
    
    tree = ttk.Treeview(columns=columns, show="headings")

    for col in columns:
        tree.heading(col, text=col.title())
        tree.column(col, minwidth=100, width=300, stretch=tk.YES)

    for item in rows:
        tree.insert('', 'end', values=item)

    tree.pack(fill='both', expand=1)
    
    def onClick(event):
        item = tree.selection()[0]
        print("\t".join(tree.item(item, "values")))
        exit(0)

    tree.bind("<Double-1>", onClick)
    center(root)
    root.mainloop()
    exit(255)

def show_wait(title, text):
    root = tk.Tk()
    root.title(title)
    label = tk.Label(text=text)
    label.pack()
    
    processing_bar = ttk.Progressbar(root, orient='horizontal', mode='indeterminate')
    processing_bar.pack(fill='both', expand=1, padx=10, pady=10)
    
    processing_bar.start(30)
    center(root)
    root.mainloop()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Simple python gui dialog gregator')
    parser.add_argument('cmd', nargs=1, type=str)
    parser.add_argument('--title', type=str)
    parser.add_argument('--text', type=str)
    parser.add_argument('--column', action='append')
    args = parser.parse_args(argv[1:])

    if len(args.cmd) == 0:
        exit(255)
    
    if args.cmd[0] == 'LIST':
        show_list(args.title, args.column)
    if args.cmd[0] == 'GET_PASS':
        get_pass(args.title, args.text)
    if args.cmd[0] == 'SHOW_TEXT':
        show_msg(args.title, args.text)
    if args.cmd[0] == 'SHOW_WAIT':
        show_wait(args.title, args.text)
    if args.cmd[0] == 'YESNO':
        answer = yesno(args.title, args.text)
        if answer == "yes":
            exit(0)
        else:
            exit(1)

