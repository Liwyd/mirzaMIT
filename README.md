# mirzaMIT

MIT VPN Bot — A feature-rich Telegram bot for managing VPN/proxy panels with MIT Panel integration.

## Features

- **8 Panel Types Supported**: Marzban, Marzneshin, MIT Panel, X-UI Single, Alireza, S-UI, WGDashboard, Mikrotik
- **MIT Panel Integration**: Dual-server architecture (MIT Panel for writes, direct Marzban for reads)
- **Payment Gateways**: Cart-to-Cart, NowPayments (crypto), AqayePardakht, IranPay/TRX
- **Full Admin Panel**: User management, product management, billing, affiliate system
- **Automated Cron Jobs**: Expiry warnings, volume warnings, auto-removal, test account cleanup
- **Service Cancellation Flow**: User-initiated with admin approval and refund
- **Discount & Gift Code System**: Percentage-based discounts, gift codes, affiliate commissions
- **Multi-language**: Persian/Farsi UI with customizable text strings
- **Spam Protection**: Rate limiting and message flood detection
- **Channel Verification**: Force users to join channels before using the bot
- **Phone Verification**: Optional Iranian phone number validation
- **Test Accounts**: Free trial VPN accounts with configurable limits

## Supported Panel Types

| Panel Type | API Style |
|------------|-----------|
| Marzban | REST API with Bearer token |
| Marzneshin | REST API with Bearer token |
| MIT Panel | Dual-server: MIT Panel API + direct Marzban reads |
| X-UI Single | Cookie-based login |
| Alireza Single | Cookie-based login |
| S-UI | REST API |
| WGDashboard | REST API with API key |
| Mikrotik | REST API with Basic Auth |

## Installation

### Prerequisites
- Ubuntu 20.04+ / Debian 11+
- Root access
- A domain pointing to your server
- Telegram Bot Token (from @BotFather)
- MIT Panel instance (or any supported panel)

### Quick Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Liwyd/mirzaMIT/master/install.sh)
```

### Manual Install

1. Clone the repository:
```bash
git clone https://github.com/Liwyd/mirzaMIT.git /var/www/html/mitbot
```

2. Navigate to the bot directory:
```bash
cd /var/www/html/mitbot
```

3. Run the installer:
```bash
chmod +x install.sh
./install.sh
```

4. Follow the interactive menu to configure your bot.

## MIT Panel Setup

1. Install MIT Panel on your server (separate from the bot)
2. In the bot admin panel, go to **Manage Panel** → **Add Panel**
3. Enter the MIT Secret Code when prompted
4. Select **MIT Panel** as the panel type
5. Enter your MIT Panel credentials:
   - MIT Panel URL (e.g., `https://panel.example.com/dashboard`)
   - MIT Panel admin username
   - MIT Panel admin password
   - Direct Marzban URL (the real Marzban instance behind MIT Panel)
6. Configure inbounds and protocol settings

## Configuration

The bot configuration is stored in `config.php` with these placeholders:

| Placeholder | Description |
|-------------|-------------|
| `{DATABASE_NAME}` | MySQL database name |
| `{DATABASE_USERNAME}` | MySQL username |
| `{DATABASE_PASSOWRD}` | MySQL password |
| `{BOT_TOKEN}` | Telegram bot token |
| `{ADMIN_#ID}` | Admin Telegram ID |
| `{DOMAIN.COM/PATH/BOT}` | Bot domain path |
| `{BOT_USERNAME}` | Bot username (without @) |
| `{MIT_SECRET}` | Secret code for MIT Panel management |

## Database Compatibility

This bot is backward-compatible with older mirzabanel database backups. You can import backups from previous versions using the installer's **Import Database** option.

## Telegram

- Channel: [@MITvpn](https://t.me/MITvpn)
- Support: [@MITsupports](https://t.me/MITsupports)

## License

GPL v3 - See [LICENSE](LICENSE) for details.

## Credits

Based on [botmirzapanel](https://github.com/mahdiMGF2/botmirzapanel) by mahdiMGF2.
