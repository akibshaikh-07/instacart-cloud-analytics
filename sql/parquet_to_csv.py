# converts the cleaned parquet files to csv so mysql can bulk load them
# input: data/*.parquet (downloaded from the s3 cleaned/ folder)
# run from the folder that has data/ in it

import pandas as pd

for name in ["products", "orders", "order_products"]:
    df = pd.read_parquet(f"data/{name}.parquet")
    print(name, df.shape, list(df.columns))

    if name == "orders":
        # parquet has True/False, mysql tinyint needs 1/0
        df["is_first_order"] = df["is_first_order"].astype("int8")

    df.to_csv(
        f"data/{name}.csv",
        index=False,
        header=False,         # columns already exist in mysql
        na_rep="\\N",         # mysql reads \N as NULL
        lineterminator="\n",  # no windows \r\n
    )
    del df