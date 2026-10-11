import pandas as pd
RAW = "raw"
OUT = "processed"

orders = pd.read_csv(f"{RAW}/orders.csv", dtype={
    "order_id": "int32", "user_id": "int32", "eval_set": "category",
    "order_number": "int16", "order_dow": "int8",
    "order_hour_of_day": "int8", "days_since_prior_order": "float32"})
products = pd.read_csv(f"{RAW}/products.csv")
aisles = pd.read_csv(f"{RAW}/aisles.csv")
departments = pd.read_csv(f"{RAW}/departments.csv")

print("orders (raw):", orders.shape)

orders = orders[orders["eval_set"] != "test"].copy()
orders["eval_set"] = orders["eval_set"].cat.remove_unused_categories()
orders["is_first_order"] = orders["order_number"] == 1

print("orders (after dropping test):", orders.shape)
print(orders["eval_set"].value_counts())

op_dtypes = {"order_id": "int32", "product_id": "int32",
             "add_to_cart_order": "int16", "reordered": "int8"}
op_prior = pd.read_csv(f"{RAW}/order_products__prior.csv", dtype=op_dtypes)
op_train = pd.read_csv(f"{RAW}/order_products__train.csv", dtype=op_dtypes)

op = pd.concat([op_prior, op_train], ignore_index=True)
del op_prior, op_train
print("order_products (prior + train):", op.shape)

print("orphan order_ids in items:", (~op["order_id"].isin(orders["order_id"])).sum())
print("orphan product_ids in items:", (~op["product_id"].isin(products["product_id"])).sum())
print("orders without items:", (~orders["order_id"].isin(op["order_id"])).sum())
print("orphan aisle_ids in products:", (~products["aisle_id"].isin(aisles["aisle_id"])).sum())
print("orphan department_ids in products:", (~products["department_id"].isin(departments["department_id"])).sum())
print("duplicate (order_id, product_id):", op.duplicated(["order_id", "product_id"]).sum())
products = products.merge(aisles, on="aisle_id").merge(departments, on="department_id")
print("products (enriched):", products.shape)

orders.to_parquet(f"{OUT}/orders.parquet", index=False)
op.to_parquet(f"{OUT}/order_products.parquet", index=False)
products.to_parquet(f"{OUT}/products.parquet", index=False)
print("saved to", OUT)
