from tkinter import ttk
import tkinter as tk

import argparse
from sys import argv, stdin

def center_and_style(win):
    win.style = ttk.Style()
    win.style.theme_use("clam")

    win.update_idletasks()
    
    width = win.winfo_width()
    height = win.winfo_height()
    x = (win.winfo_screenwidth() // 2) - (width // 2)
    y = (win.winfo_screenheight() // 2) - (height // 2)
    win.geometry('{}x{}+{}+{}'.format(width, height, x, y))

def yesno(root, text):
    text = ttk.Label(root, text=text)

    buttonFrame= ttk.Frame(root)
    noButton = ttk.Button(buttonFrame, text="No", command= lambda: exit(1))

    yesButton = ttk.Button(buttonFrame, text="Yes", command= lambda: exit(0))

    text.pack(expand=1)
    yesButton.pack(side=tk.RIGHT, padx=10, pady=10)
    noButton.pack(side=tk.RIGHT, padx=10, pady=10)
    buttonFrame.pack(fill='both', expand=1)
    
    center_and_style(root)
    root.mainloop()
    exit(255)

def show_msg(root, text):
    msg = ttk.Label(root, text=text)

    buttonFrame= ttk.Frame(root)
    okButton = ttk.Button(buttonFrame, text="Ok", command= lambda: exit(0))

    msg.pack(pady=10, padx=10)
    okButton.pack(side=tk.RIGHT, padx=10, pady=10)
    buttonFrame.pack(fill='both', expand=1)
    
def get_pass(root, text):
    passwordtext = ttk.Label(root, text=text)
    passwordguess = ttk.Entry(root, show="*") 
    
    buttonFrame= ttk.Frame(root)
    cancelButton = ttk.Button(buttonFrame, text="Cancel", command= lambda: exit(255))

    def okButtonClicked(event=None):    
        print(passwordguess.get())
        exit(0)

    okButton = ttk.Button(buttonFrame, text="Ok", command= okButtonClicked)
    root.bind('<Return>', okButtonClicked)

    passwordtext.pack(pady=3, padx=10)
    passwordguess.pack(fill='both', expand=1, padx=10, ipady=3)
    okButton.pack(side=tk.RIGHT, padx=10)
    cancelButton.pack(side=tk.RIGHT, padx=10)
    buttonFrame.pack(fill='x', expand=1, padx=10, pady=3)
    

def show_list(root, columns):
    rows=[]

    for line in stdin:
        rows.append(line[:-1].split("\t"))
    
    tree = ttk.Treeview(columns=columns, show="headings")

    for col in columns:
        tree.heading(col, text=col.title())
        tree.column(col, minwidth=100, width=300, stretch=tk.YES)

    for item in rows:
        tree.insert('', 'end', values=item)

    buttonFrame= ttk.Frame(root)
    cancelButton = ttk.Button(buttonFrame, text="Cancel", command= lambda: exit(255))
    
    
    def okButtonClicked(event):
        item = tree.selection()[0]
        print("\t".join(tree.item(item, "values")))
        exit(0)

    tree.bind("<Double-1>", okButtonClicked)
    
    okButton = ttk.Button(buttonFrame, text="OK", command= okButtonClicked)
    
    tree.pack(fill='both', expand=1)
    okButton.pack(side=tk.RIGHT, padx=10, pady=10)
    cancelButton.pack(side=tk.LEFT, padx=10, pady=10)
    buttonFrame.pack(fill='x', expand=1)

def show_wait(root, text):
    label = ttk.Label(text=text)
    
    processing_bar = ttk.Progressbar(root, orient='horizontal', mode='indeterminate')
    
    label.pack(padx=10, pady=3)
    processing_bar.pack(fill='both', expand=1, padx=10, pady=10)
    
    processing_bar.start(30)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Simple python gui dialog gregator')
    parser.add_argument('cmd', nargs=1, type=str)
    parser.add_argument('--title', type=str)
    parser.add_argument('--text', type=str)
    parser.add_argument('--column', action='append')
    parser.add_argument('--extra', nargs=2, action='append')

    args = parser.parse_args(argv[1:])

    if len(args.cmd) == 0:
        exit(255)
    
    root = tk.Tk()
    root.title(args.title)

    if args.cmd[0] == 'LIST':
        show_list(root, args.column)
    if args.cmd[0] == 'GET_PASS':
        get_pass(root, args.text)
    if args.cmd[0] == 'SHOW_TEXT':
        show_msg(root, args.text)
    if args.cmd[0] == 'SHOW_WAIT':
        show_wait(root, args.text)
    if args.cmd[0] == 'YESNO':
        answer = yesno(root, args.text)
        if answer == "yes":
            exit(0)
        else:
            exit(1)

    center_and_style(root)
    root.mainloop()
    exit(255)
