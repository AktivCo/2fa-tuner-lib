from sys import argv
from functools import reduce

if __name__ == "__main__":
    if len(argv) != 2:
        exit(1)

    public_keys=[]
    private_keys=[]
    certificates=[]

    current_list= None
    for line in argv[1].split("\n"):
        if len(line) == 0:
            continue
        if not line[0].isspace():
            if line.startswith("Public"):
                current_list=public_keys
            elif line.startswith("Private"):
                current_list=private_keys
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
   
    all_attributes=set()
    for object_list in [public_keys, private_keys, certificates]:
        attributes = reduce(lambda attrs, obj: attrs.union(obj.keys()), object_list, set())
        all_attributes.update(attributes)
    
    all_attributes=["ID", "label"] + sorted(all_attributes.difference({"ID", "label"}))
    
    print("TYPE\t" + "\t".join(all_attributes))
    for object_list, _type in [(public_keys, "pub"), (private_keys, "priv"), (certificates, "cert")]:
        for obj in object_list:
            yad_string = f"{_type}"
            for attr in all_attributes:
                yad_string += f'\t{obj.get(attr,"")}'
            print(yad_string)
