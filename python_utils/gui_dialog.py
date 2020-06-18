from tkinter import ttk
import tkinter as tk
from tkinter import filedialog

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
    yesButton.focus_set()
    noButton.pack(side=tk.RIGHT, padx=10, pady=10)
    buttonFrame.pack(fill='x', side=tk.BOTTOM)

def show_msg(root, text):
    msg = ttk.Label(root, text=text)

    buttonFrame= ttk.Frame(root)
    okButton = ttk.Button(buttonFrame, text="Ok", command= lambda: exit(0))
    root.bind('<Return>', lambda x: exit(0))

    msg.pack(pady=10, padx=10)
    okButton.pack(side=tk.RIGHT, padx=10, pady=10)
    buttonFrame.pack(fill='x', side=tk.BOTTOM)

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
    passwordguess.focus_set()
    okButton.pack(side=tk.RIGHT, padx=10)
    cancelButton.pack(side=tk.RIGHT, padx=10)
    buttonFrame.pack(fill='x', padx=10, pady=3, side=tk.BOTTOM)

def show_list(root, columns):
    rows=[]

    for line in stdin:
        rows.append(line[:-1].split("\t"))
    
    tree = ttk.Treeview(root, columns=columns, show="headings")

    for col in columns:
        tree.heading(col, text=col.title())
        tree.column(col)

    for item in rows:
        tree.insert('', 'end', values=item)

    child_id = tree.get_children()[0]
    tree.focus(child_id)
    tree.selection_set(child_id)

    buttonFrame= ttk.Frame(root)
    cancelButton = ttk.Button(buttonFrame, text="Cancel", command= lambda: exit(255))
    
    def okButtonClicked(event=None):
        item = tree.selection()[0]
        if tree.item(item, "values") == "":
            return

        print("\t".join(tree.item(item, "values")))
        exit(0)
    
    def arrowDown(event=None):
        item = tree.selection()[0]
        next_item = tree.next(item)

        if tree.item(next_item, "values") == "":
            return

        tree.focus(next_item)
        tree.selection_set(next_item)

    def arrowUp(event=None):
        item = tree.selection()[0]
        prev_item = tree.prev(item)
        
        if tree.item(prev_item, "values") == "":
            return

        tree.focus(prev_item)
        tree.selection_set(prev_item)

    tree.bind("<Double-1>", okButtonClicked)
    root.bind('<Return>', okButtonClicked)
    root.bind('<Down>', arrowDown)
    root.bind('<Up>', arrowUp)

    okButton = ttk.Button(buttonFrame, text="OK", command= okButtonClicked)
    
    tree.pack(fill='both', expand=1)
    okButton.pack(side=tk.RIGHT, padx=10, pady=10)
    cancelButton.pack(side=tk.LEFT, padx=10, pady=10)
    buttonFrame.pack(fill='x', side=tk.BOTTOM)

def show_wait(root, text):
    label = ttk.Label(text=text)
    
    processing_bar = ttk.Progressbar(root, orient='horizontal', mode='indeterminate')
    
    label.pack(padx=10, pady=3)
    processing_bar.pack(fill='both', expand=1, padx=10, pady=10)
    
    processing_bar.start(30)

def save_file(root, title, file, start_dir):
    root.withdraw()
    root.style = ttk.Style()
    root.style.theme_use("clam")

    target = filedialog.asksaveasfilename(parent=root, title=title, initialdir=start_dir)
    if target:
        print(target)
        exit(0)
    else:
        exit(255)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Simple python gui dialog gregator')
    parser.add_argument('cmd', nargs=1, type=str)
    parser.add_argument('--title', type=str)
    parser.add_argument('--text', type=str)
    parser.add_argument('--column', type=str)
    parser.add_argument('--extra', nargs=2, action='append')
    parser.add_argument('--file', type=str)
    parser.add_argument('--start_dir', type=str)

    args = parser.parse_args(argv[1:])

    if len(args.cmd) == 0:
        exit(255)
    
    root = tk.Tk()
    root.title(args.title)

    if args.cmd[0] == 'LIST':
        show_list(root, args.column.split("\t"))
    if args.cmd[0] == 'GET_PASS':
        get_pass(root, args.text)
    if args.cmd[0] == 'SHOW_TEXT':
        show_msg(root, args.text)
    if args.cmd[0] == 'SHOW_WAIT':
        show_wait(root, args.text)
    if args.cmd[0] == 'YESNO':
        yesno(root, args.text)
    if args.cmd[0] == 'SAVE_FILE':
        save_file(root, args.title, args.file, args.start_dir)

    if args.extra:
        extraButtonFrame= ttk.Frame(root)
        for cmd_name, cmd in args.extra:
            def onClickCmd():
                print(cmd)
                exit(0)
            btn = ttk.Button(extraButtonFrame, text=cmd_name, command=onClickCmd)
            btn.pack(side=tk.RIGHT, padx=10, fill="x", expand=1)
        extraButtonFrame.pack(fill="x")

    root.bind("<Escape>", lambda x: exit(255))

    center_and_style(root)
    root.mainloop()
    exit(255)
