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
    
    attr_name_map = {
            "id": "Идентификатор",
            "label": "Метка",
            "subject": "Кому выдан",
            "usage": "Назначение",
            "type": "Свойства"}

    renamed_all_attributes=[ attr_name_map[x.lower()] for x in all_attributes ]

    print("Тип\t" + "\t".join(renamed_all_attributes))
    for object_list, _type in [(public_keys, "Открытый ключ"), (private_keys, "Закрытый ключ"), (certificates, "Сертификат")]:
        for obj in object_list:
            yad_string = _type
            for attr in all_attributes:
                yad_string += "\t" + obj.get(attr,"")
            print(yad_string)
