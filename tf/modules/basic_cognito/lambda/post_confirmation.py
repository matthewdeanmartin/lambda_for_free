def handler(event, context):
    print("Post-confirmation trigger invoked")
    print(event)
    # Optional: auto-assign "free user" group logic here
    return event