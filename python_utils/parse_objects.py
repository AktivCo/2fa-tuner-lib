from sys import argv
from functools import reduce

if __name__ == "__main__":
    if len(argv) != 2:
        exit(1)

    public_keys=[]
    privte_keys=[]
    certificates=[]

    current_list= None
    for line in argv[1].split("\n"):
        if len(line) == 0:
            continue
        if not line[0].isspace():
            if line.startswith("Public"):
                current_list=public_keys
            elif line.startswith("Private"):
                current_list=pivate_keys
            elif line.startswith("Certificate"):
                current_list = certificates
            else:
                exit(2)
            current_list.append({})
            current_list[-1]["type"] = line.split(";",1)[-1].strip()
            continue
        if current_list == None:
            exit(3)
        current_list[-1][line.split(":",1)[0].strip()] = line.split(":",1)[-1].strip()

    
    for object_list in [public_keys, privte_keys, certificates]:
        attributes = reduce(lambda attrs, obj: attrs.union(obj.keys()), object_list, set())
        attributes = sorted(attributes)
        yad_string = "--list "
        yad_string += "".join(map(lambda attr: f' --column "{attr}"', attributes))
        for obj in object_list:
            for attr in attributes:
                yad_string += f' "{obj.get(attr,"")}"'
        print(yad_string)

