import webbrowser


def open_browser(url: str = "https://www.example.com") -> None:
    """Open the default web browser at the specified URL."""
    webbrowser.open(url)


if __name__ == "__main__":
    open_browser()
