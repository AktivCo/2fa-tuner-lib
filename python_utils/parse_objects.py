from sys import argv, stderr
from functools import reduce

if __name__ == "__main__":
    if len(argv) < 2:
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
            current_list.append({})
            
            atr = "type"
            val = line.split(";",1)[-1].strip()
            if val == "unknown key algorithm 3560050691":
                val = "GOSTR3410-2012-512"
            
            current_list[-1][atr] = val
            continue
        
        if line.count(":"):
            atr = line.split(":",1)[0].strip().lower()
            val = line.split(":",1)[-1].strip()
            current_list[-1][atr] = val 
        else:
            current_list[-1][atr] = current_list[-1][atr] + line.strip()
    all_attributes=set()
    for object_list in [public_keys, private_keys, certificates]:
        attributes = reduce(lambda attrs, obj: attrs.union(obj.keys()), object_list, set())
        all_attributes.update(attributes)

    if len(argv) = 5:
        type_ = argv[2]
        arg = argv[3]
        val = argv[4]
        current_list=[]
        if type_ == "pub":
            current_list = public_keys
        elif type_ == "priv":
            current_list = private_keys
        elif type_ == "cert":
            current_list = certificates

        obj=filter(lambda x: x.get(arg) == val, current_list)
        if len(obj) > 0:
            print(obj[0])
        exit(0)
    all_attributes.discard("value")
    all_attributes.discard("params oid")
    all_attributes.discard("access")
    all_attributes=["id", "label"] + sorted(all_attributes.difference({"id", "label"}))

    attr_name_map = {
            "id": "Идентификатор",
            "label": "Метка",
            "subject": "Кому выдан",
            "usage": "Назначение",
            "type": "Свойства",
            "access": "Доступ",
            "value": "Значение",
            "params oid": "OID параметров"}

    renamed_all_attributes=[ attr_name_map[x] for x in all_attributes ]

    print("Тип\t" + "\t".join(renamed_all_attributes))
    for object_list, _type in [(public_keys, "Открытый ключ"), (private_keys, "Закрытый ключ"), (certificates, "Сертификат")]:
        for obj in object_list:
            yad_string = _type
            for attr in all_attributes:
                yad_string += "\t" + obj.get(attr,"")
            print(yad_string)
