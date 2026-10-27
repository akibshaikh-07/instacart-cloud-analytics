import getpass
import os

import pandas as pd
import pymysql

TABLES = ["fact_orders", "fact_items", "fact_gap", "fact_products", "fact_pairs",
          "dim_department", "dim_segment", "dim_day", "dim_hour"]

pw = getpass.getpass("MySQL root password: ")
conn = pymysql.connect(host="localhost", user="root", password=pw, database="instacart")

os.makedirs("powerbi_data", exist_ok=True)

with pd.ExcelWriter("powerbi_data/instacart_model.xlsx", engine="openpyxl") as xl:
    for t in TABLES:
        cur = conn.cursor()
        cur.execute(f"SELECT * FROM {t}")
        cols = [c[0] for c in cur.description]
        df = pd.DataFrame(cur.fetchall(), columns=cols)
        df.to_excel(xl, sheet_name=t, index=False)
        print(t, df.shape)

conn.close()