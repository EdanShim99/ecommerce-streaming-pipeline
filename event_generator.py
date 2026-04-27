import json
import random
import time
import uuid
import argparse
from datetime import datetime, UTC, timedelta
import boto3


CATEGORIES = [
    "Electronics", "Clothing", "Home & Kitchen", "Sports",
    "Books", "Beauty", "Toys", "Grocery"
]

PRODUCTS = {}
for i in range(1, 101):
    cat = CATEGORIES[i % len(CATEGORIES)]
    PRODUCTS[i] = {
        "product_name": f"{cat.split(' ')[0]}_{i}",
        "category": cat,
        "base_price": round(10 + (i * 4.87) % 490, 2)
    }

SEARCH_TERMS = [
    "laptop", "running shoes", "headphones", "winter jacket",
    "coffee maker", "yoga mat", "phone case", "novel",
    "face cream", "dumbbells", "kids toy", "organic snacks"
]

EVENT_TYPES = ["page_view", "add_to_cart", "purchase", "search"]
DEVICE_TYPES = ["mobile", "desktop", "tablet"]

user_sessions = {}
SESSION_TIMEOUT = timedelta(minutes=5)


def get_session(user_id):
    now = datetime.now(UTC)
    if user_id in user_sessions:
        session_id, last_seen = user_sessions[user_id]
        if now - last_seen < SESSION_TIMEOUT:
            user_sessions[user_id] = (session_id, now)
            return session_id
    session_id = str(uuid.uuid4())
    user_sessions[user_id] = (session_id, now)
    return session_id


def generate_event():
    event_type = random.choices(
        EVENT_TYPES,
        weights=[0.50, 0.20, 0.10, 0.20],
        k=1
    )[0]

    user_id = random.randint(1, 1000)
    product_id = random.randint(1, 100)
    product = PRODUCTS[product_id]

    event = {
        "event_id": str(uuid.uuid4()),
        "user_id": user_id,
        "session_id": get_session(user_id),
        "event_type": event_type,
        "product_id": product_id,
        "product_name": product["product_name"],
        "category": product["category"],
        "price": product["base_price"],
        "quantity": random.randint(1, 3) if event_type == "purchase" else 1,
        "device_type": random.choice(DEVICE_TYPES),
        "event_timestamp": datetime.now(UTC).isoformat()
    }

    if event_type == "search":
        event["search_query"] = random.choice(SEARCH_TERMS)

    return event


def corrupt_event(event):
    corruptions = [
        lambda e: {k: v for k, v in e.items() if k != "price"},
        lambda e: {**e, "price": "not_a_number"},
        lambda e: {**e, "user_id": None},
        lambda e: {**e, "event_type": ""},
        lambda e: {k: v for k, v in e.items() if k != "event_timestamp"},
    ]
    return random.choice(corruptions)(event)


def send_batch(kinesis, stream_name, batch):
    records = [
        {
            "Data": json.dumps(event) + "\n",
            "PartitionKey": str(event.get("user_id", "unknown"))
        }
        for event in batch
    ]

    try:
        response = kinesis.put_records(
            StreamName=stream_name,
            Records=records
        )
        failed = response.get("FailedRecordCount", 0)
        sent = len(records) - failed
        print(f"Sent {sent} events | Failed: {failed}")
    except Exception as e:
        print(f"Error sending batch: {e}")


def main():
    parser = argparse.ArgumentParser(description="E-commerce event generator")
    parser.add_argument("--burst", action="store_true", help="High throughput burst mode")
    parser.add_argument("--region", default="us-west-1")
    parser.add_argument("--stream", default="ecommerce-events-stream")
    args = parser.parse_args()

    kinesis = boto3.client("kinesis", region_name=args.region)

    batch_size = 50 if args.burst else 10
    sleep_min = 0.05 if args.burst else 0.5
    sleep_max = 0.2 if args.burst else 2.0
    malformed_rate = 0.05

    mode = "BURST" if args.burst else "NORMAL"
    print(f"Generator started | Mode: {mode} | Batch: {batch_size} | Stream: {args.stream}")

    while True:
        batch = []
        for _ in range(batch_size):
            event = generate_event()
            if random.random() < malformed_rate:
                event = corrupt_event(event)
            batch.append(event)

        send_batch(kinesis, args.stream, batch)
        time.sleep(random.uniform(sleep_min, sleep_max))


if __name__ == "__main__":
    main()