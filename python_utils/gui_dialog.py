from tkinter import messagebox
from tkinter import simpledialog
from tkinter import ttk
import tkinter as tk

import argparse
from sys import argv, stdin

def yesno(title, text):
    tk.Tk().withdraw()
    return messagebox.askquestion (title, text)

def show_msg(title, text):
    tk.Tk().withdraw()
    messagebox.showinfo(title, text)

def get_pass(title, text):
    tk.Tk().withdraw()
    return simpledialog.askstring(title, text, show='*')

def show_list(title, columns):
    root = tk.Tk()
    root.title(title)
    rows=[]

    for line in stdin:
        rows.append(line[:-1].split("\t"))
    
    tree = ttk.Treeview(columns=columns, show="headings")

    for col in columns:
        tree.heading(col, text=col.title())
    for item in rows:
        tree.insert('', 'end', values=item)
    
    tree.pack(fill='both', expand=1)
    
    def onClick(event):
        item = tree.selection()[0]
        print("\t".join(tree.item(item, "values")))
        exit(0)

    tree.bind("<Double-1>", onClick)
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
        print(show_list(args.title, args.column))
    if args.cmd[0] == 'GET_PASS':
        print(get_pass(args.title, args.text))
    if args.cmd[0] == 'SHOW_TEXT':
        show_msg(args.title, args.text)
    if args.cmd[0] == 'YESNO':
        answer = yesno(args.title, args.text)
        if answer == "yes":
            exit(0)
        else:
            exit(1)

