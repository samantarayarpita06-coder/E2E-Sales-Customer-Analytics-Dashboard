"""
generate_and_seed_ecom.py
Run: python generate_and_seed_ecom.py
Edit top params to change sizes.
"""

import random
import string
from datetime import datetime, timedelta
from faker import Faker
import pandas as pd
from sqlalchemy import create_engine, text
from dateutil import tz
from tqdm import tqdm

# ---------- PARAMETERS ----------
NUM_CUSTOMERS = 5000        # adjust
NUM_SUPPLIERS = 50
NUM_WAREHOUSES = 8
NUM_CATEGORIES = 25
NUM_PRODUCTS = 800
NUM_ORDERS = 70000         # big -> adjust if heavy
MAX_ITEMS_PER_ORDER = 5

# MySQL connection (update user/password/host/db)
DB_USER = "root"
DB_PASS = "RolexDaytona27"
DB_HOST = "127.0.0.1"
DB_PORT = 3306
DB_NAME = "ecom_maang"

# ---------- SETUP ----------
fake = Faker()
Faker.seed(1234)
random.seed(42)

conn_str = f"mysql+pymysql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}?charset=utf8mb4"
engine = create_engine(conn_str, pool_size=10, max_overflow=20)

# helper id formatters
def cid(i): return f"C{str(i).zfill(5)}"
def pid(i): return f"P{str(i).zfill(5)}"
def sid(i): return f"S{str(i).zfill(4)}"
def wid(i): return f"W{str(i).zfill(3)}"
def oid(i): return f"O{str(i).zfill(8)}"
def shid(i): return f"SH{str(i).zfill(8)}"
def rid(i): return f"R{str(i).zfill(8)}"

# currencies sample
CURRENCIES = ["USD","EUR","INR","GBP","JPY","AUD","CAD"]
TIMEZONES = ["UTC","Asia/Kolkata","Europe/London","America/New_York","Asia/Singapore","Europe/Berlin","America/Los_Angeles"]

# ---------- GENERATE ----------
print("Generating customers...")
customers = []
for i in range(1, NUM_CUSTOMERS+1):
    tz_name = random.choice(TIMEZONES)
    created = fake.date_time_between(start_date='-3y', end_date='now')
    customers.append({
        "customer_id": cid(i),
        "name": fake.name(),
        "email": f"user{i}@{fake.free_email_domain()}",
        "created_at": created,
        "country": fake.country(),
        "timezone": tz_name
    })
customers_df = pd.DataFrame(customers)

print("Generating suppliers...")
suppliers = []
for i in range(1, NUM_SUPPLIERS+1):
    suppliers.append({
        "supplier_id": sid(i),
        "name": fake.company(),
        "rating": round(random.uniform(2.5,5.0),2),
        "country": fake.country()
    })
suppliers_df = pd.DataFrame(suppliers)

print("Generating warehouses...")
warehouses = []
cities = ["Mumbai","Bengaluru","Delhi","London","New York","Berlin","Singapore","Sydney"]
for i in range(1, NUM_WAREHOUSES+1):
    warehouses.append({
        "warehouse_id": wid(i),
        "name": f"WH-{i}",
        "country": fake.country(),
        "city": random.choice(cities),
        "capacity": random.randint(10000,200000)
    })
warehouses_df = pd.DataFrame(warehouses)

print("Generating categories (hierarchy)...")
categories = []
# create top-level categories
for i in range(1, NUM_CATEGORIES+1):
    parent = None
    if i > 5:
        # some will be children of earlier ones
        parent = random.randint(1, min(5, i-1))
    categories.append({
        "category_id": i,
        "name": f"Category {i}",
        "parent_id": parent
    })
categories_df = pd.DataFrame(categories)

print("Generating products...")
products = []
for i in range(1, NUM_PRODUCTS+1):
    cat = random.randint(1, NUM_CATEGORIES)
    supp = sid(random.randint(1, NUM_SUPPLIERS))
    price_usd = round(random.uniform(5,2000),2)
    currency = random.choice(CURRENCIES)
    created = fake.date_time_between(start_date='-2y', end_date='now')
    products.append({
        "product_id": pid(i),
        "name": f"Product {i} {fake.word()}",
        "category_id": cat,
        "supplier_id": supp,
        "price_usd": price_usd,
        "currency": currency,
        "created_at": created
    })
products_df = pd.DataFrame(products)

print("Generating exchange rates...")
# Simulated rates
rates = {
    "USD": 1.0,
    "EUR": 1.08,
    "INR": 0.012,
    "GBP": 1.25,
    "JPY": 0.0068,
    "AUD": 0.64,
    "CAD": 0.74
}
exchange = []
today = datetime.utcnow().date()
for cur, r in rates.items():
    exchange.append({"currency": cur, "rate_to_usd": r, "last_updated": today})
exchange_df = pd.DataFrame(exchange)

# ---------- ORDERS & ITEMS ----------
print("Generating orders and items (this may take a while)...")
orders = []
order_items = []
shipments = []
returns = []

order_id_counter = 1
shipment_counter = 1
return_counter = 1
item_counter = 1

for i in tqdm(range(1, NUM_ORDERS+1)):
    o_id = oid(i)
    cust_idx = random.randint(1, NUM_CUSTOMERS)
    cust = customers_df.loc[cust_idx-1]
    # pick a timezone maybe matching customer
    tz_name = cust['timezone']
    order_dt = fake.date_time_between(start_date='-1y', end_date='now')
    currency = random.choice(CURRENCIES)
    items_count = random.randint(1, MAX_ITEMS_PER_ORDER)
    total = 0.0
    for j in range(items_count):
        prod_idx = random.randint(1, NUM_PRODUCTS)
        prod = products_df.loc[prod_idx-1]
        qty = random.randint(1, 4)
        # unit price in product currency; convert to order currency by using USD base
        unit_usd = prod['price_usd']
        # simulate small price variation
        unit_usd = round(unit_usd * random.uniform(0.8,1.2),2)
        # convert unit_usd to order currency:
        rate_to_usd = rates[currency]
        # amount in order currency ~ unit_usd / rate_to_usd (since rate_to_usd is currency->USD)
        if rate_to_usd == 0: rate_to_usd = 1.0
        unit_price_order_currency = round(unit_usd / rate_to_usd, 2)
        total += unit_price_order_currency * qty
        order_items.append({
            "order_id": o_id,
            "product_id": prod['product_id'],
            "quantity": qty,
            "unit_price": unit_price_order_currency
        })
    status = random.choices(
        ["placed","shipped","delivered","cancelled","returned"],
        weights=[0.05,0.25,0.6,0.05,0.05], k=1)[0]
    warehouse = wid(random.randint(1, NUM_WAREHOUSES))
    shipping_delay = max(0, int(random.gauss(12,10)))  # hours
    orders.append({
        "order_id": o_id,
        "customer_id": cust['customer_id'],
        "order_datetime": order_dt,
        "order_timezone": tz_name,
        "total_amount": round(total,2),
        "currency": currency,
        "status": status,
        "warehouse_id": warehouse,
        "shipping_delay_hours": shipping_delay
    })
    # shipments
    shipped_at = order_dt + timedelta(hours=random.randint(1,48))
    delivered_at = shipped_at + timedelta(hours=random.randint(12,240))
    shipments.append({
        "shipment_id": shid(shipment_counter),
        "order_id": o_id,
        "shipped_at": shipped_at,
        "delivered_at": delivered_at if status in ("delivered","returned") else None,
        "status": status,
        "carrier": random.choice(["DHL","FedEx","BlueDart","IndiaPost","UPS","ShipRocket"])
    })
    shipment_counter += 1

    # returns sometimes
    if status == "returned" or random.random() < 0.02:
        # create a return row for one item
        some_item = random.choice(order_items[-items_count:])
        ret_amt = round(some_item['unit_price'] * some_item['quantity'] * random.uniform(0.5,1.0),2)
        returns.append({
            "return_id": rid(return_counter),
            "order_id": o_id,
            "product_id": some_item['product_id'],
            "return_reason": random.choice(["Damaged","Not as described","Wrong item","Buyer remorse"]),
            "return_datetime": shipped_at + timedelta(days=random.randint(2,20)),
            "refund_amount": ret_amt
        })
        return_counter += 1

# convert to dataframes
orders_df = pd.DataFrame(orders)
order_items_df = pd.DataFrame(order_items)
shipments_df = pd.DataFrame(shipments)
returns_df = pd.DataFrame(returns)

# ---------- SAVE CSVs (optional) ----------
print("Saving CSVs (customers/products/orders...)")
customers_df.to_csv("customers.csv", index=False)
suppliers_df.to_csv("suppliers.csv", index=False)
warehouses_df.to_csv("warehouses.csv", index=False)
categories_df.to_csv("categories.csv", index=False)
products_df.to_csv("products.csv", index=False)
exchange_df.to_csv("exchange_rates.csv", index=False)
orders_df.to_csv("orders.csv", index=False)
order_items_df.to_csv("order_items.csv", index=False)
shipments_df.to_csv("shipments.csv", index=False)
returns_df.to_csv("returns.csv", index=False)

# ---------- INSERT INTO MySQL ----------
print("Inserting into MySQL (in order). This will use SQLAlchemy bulk inserts.")
with engine.begin() as conn:
    conn.execute(text("SET FOREIGN_KEY_CHECKS = 0;"))
    # truncate existing
    for tbl in ["returns","shipments","order_items","orders","products","categories","warehouses","suppliers","customers","exchange_rates"]:
        conn.execute(text(f"TRUNCATE TABLE {tbl};"))
    conn.execute(text("SET FOREIGN_KEY_CHECKS = 1;"))

    # insert small tables first
    customers_df.to_sql("customers", conn, if_exists="append", index=False, method="multi", chunksize=1000)
    suppliers_df.to_sql("suppliers", conn, if_exists="append", index=False, method="multi")
    warehouses_df.to_sql("warehouses", conn, if_exists="append", index=False, method="multi")
    categories_df.to_sql("categories", conn, if_exists="append", index=False, method="multi")
    products_df.to_sql("products", conn, if_exists="append", index=False, method="multi", chunksize=1000)
    exchange_df.to_sql("exchange_rates", conn, if_exists="append", index=False, method="multi")

    # then orders / details
    orders_df.to_sql("orders", conn, if_exists="append", index=False, method="multi", chunksize=1000)
    order_items_df.to_sql("order_items", conn, if_exists="append", index=False, method="multi", chunksize=2000)
    shipments_df.to_sql("shipments", conn, if_exists="append", index=False, method="multi")
    if not returns_df.empty:
        returns_df.to_sql("returns", conn, if_exists="append", index=False, method="multi")

print("Done. Seed complete.")
