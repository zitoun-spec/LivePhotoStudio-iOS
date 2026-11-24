# Live Photo Studio installeren op Windows met AltStore Classic

Je hebt een Windows-pc, een iPhone met iOS 17 of nieuwer, een USB-datakabel, internet en een gratis Apple Account nodig. AltServer draait op Windows en AltStore Classic ondertekent de app voor je iPhone met dit account. Je hebt geen Mac of betaald Apple Developer-lidmaatschap nodig.

## 1. Download de IPA bij GitHub Actions

1. Meld je aan bij GitHub en open de [Actions-pagina van Live Photo Studio](https://github.com/zitoun-spec/LivePhotoStudio-iOS/actions).
2. Open een run van **iPhone build and tests** bij de pull request of op de gewenste branch. Controleer dat **Unsigned iPhone IPA** is geslaagd.
3. Klik onder **Artifacts** op **LivePhotoStudio**. GitHub downloadt een ZIP als transportverpakking.
4. Pak die ZIP één keer uit. Gebruik **LivePhotoStudio.ipa**. Laat het IPA zelf intact en wijzig de extensie niet.
5. Zet **LivePhotoStudio.ipa** op je iPhone, bijvoorbeeld met iCloud Drive. Wacht indien nodig tot het bestand beschikbaar is in **Bestanden**. Je kunt het daar lokaal bewaren onder **Op mijn iPhone**.

Als een artifact is verlopen, open je een recentere succesvolle build. Heeft de repository de workflow op de standaardbranch en heb je schrijfrechten, dan kun je onder **Actions → iPhone build and tests → Run workflow** een nieuwe bouw starten. De standaard GitHub-runner gebruikt de beschikbare Actions-minuten van de repository. Voor deze openbare repository zijn standaard GitHub-hosted runners gratis. [GitHub over het downloaden van artifacts](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts) · [GitHub over Actions-kosten](https://docs.github.com/en/billing/concepts/product-billing/github-actions)

## 2. Installeer AltServer op Windows

1. Download iTunes en iCloud voor Windows via de links onder **Before Installing AltStore** in de officiële Windows-handleiding van AltStore Classic. Kies de directe Apple-versies. Als iCloud uit de Microsoft Store vereist is op jouw pc, volg dan de instructies voor die situatie in de officiële probleemoplosser.
2. Download **AltServer for Windows** via dezelfde handleiding, pak het AltServer-archief uit en voer **Setup.exe** uit.
3. Start **AltServer** als administrator. Sta privé-netwerktoegang toe als Windows Firewall erom vraagt. Het AltServer-pictogram verschijnt in het systeemvak, mogelijk onder het pijltje voor verborgen pictogrammen.
4. Sluit de ontgrendelde iPhone met USB aan. Tik bij **Vertrouw je deze computer?** op **Vertrouw** en voer de iPhone-toegangscode in.
5. Open iTunes en meld je aan met je Apple Account. Open de iPhone in iTunes, schakel synchroniseren via wifi in en klik op **Pas toe**. Houd voor de eerste installatie de kabel aangesloten.

[Officiële Windows-installatiehandleiding van AltStore Classic](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) · [Officiële probleemoplosser](https://faq.altstore.io/altstore-classic/troubleshooting-guide)

## 3. Installeer AltStore Classic op de iPhone

1. Klik op het AltServer-pictogram in het Windows-systeemvak. Kies **Install AltStore** en selecteer je iPhone.
2. Meld je in AltServer aan met je Apple Account en voltooi eventuele verificatie bij Apple. Wacht op de bevestiging van AltServer.
3. Open op de iPhone **Instellingen → Algemeen → VPN- en apparaatbeheer**. Selecteer het ontwikkelaarsprofiel van je Apple Account en volg de melding om het te vertrouwen. Start de iPhone opnieuw op als iOS daar om vraagt.
4. Ga naar **Instellingen → Privacy en beveiliging → Ontwikkelaarsmodus**. Schakel de modus in, laat de iPhone herstarten en bevestig de wijziging na het ontgrendelen. De instelling verschijnt doorgaans nadat je geprobeerd hebt AltStore te openen.
5. Open **AltStore Classic**. Meld je zo nodig in **Settings → Account** aan met hetzelfde Apple Account als in AltServer.

[Officiële Windows-installatiehandleiding](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) · [Apple over Ontwikkelaarsmodus](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)

## 4. Onderteken en installeer Live Photo Studio

1. Laat AltServer op de Windows-pc actief. Houd de USB-kabel aangesloten of verbind beide apparaten met hetzelfde privénetwerk met wifi-synchronisatie ingeschakeld.
2. Open **AltStore → My Apps** en tik op **+**.
3. Selecteer **LivePhotoStudio.ipa** in Bestanden. Wacht tot AltStore de app heeft ondertekend en geïnstalleerd. De app verschijnt onder **My Apps** en op het beginscherm of in de appbibliotheek.
4. Open Live Photo Studio. Importeer voor een eerste proef een korte video, tik op **Convert to Live Photo** en daarna op **Save Live Photo**. Geef toegang om foto’s toe te voegen wanneer iOS daarom vraagt.

## 5. Vernieuw de ondertekening elke zeven dagen

Met een gratis Apple Account verloopt de ondertekening na zeven dagen. Open op tijd **AltStore → My Apps → Refresh All** terwijl AltServer bereikbaar is. AltStore kan ook op de achtergrond proberen te vernieuwen. Als AltStore zelf is verlopen, installeer AltStore opnieuw via AltServer over de bestaande installatie heen en vernieuw daarna de apps. De al opgeslagen Live Photos staan in je Foto’s-bibliotheek.

Apple beperkt de actieve apps die je met een gratis account via AltStore installeert. Als je een limiet bereikt, kun je in **My Apps** een andere sideload-app deactiveren. AltStore documenteert ook een registratiequotum voor App IDs. [AltStore over vernieuwen](https://faq.altstore.io/altstore-classic/your-altstore) · [AltStore over App IDs](https://faq.altstore.io/altstore-classic/app-ids)

## Problemen oplossen

| Probleem | Controle |
| --- | --- |
| AltServer ziet de iPhone niet | Ontgrendel de iPhone, gebruik een andere USB-datakabel of USB-poort en controleer of iTunes de iPhone ziet en het vertrouwensvenster is bevestigd. |
| **Could not find AltServer** | Laat AltServer draaien. Probeer USB. Controleer voor wifi of iTunes wifi-synchronisatie heeft ingeschakeld, beide apparaten op hetzelfde privénetwerk zitten en AltServer door de firewall mag. |
| Windows meldt dat iCloud of iTunes ontbreekt | Controleer de installaties uit stap 2. Voor de Microsoft Store-versie van iCloud verwijst AltStore naar de eigen probleemoplosser. |
| AltStore ziet het IPA niet | Pak de download van GitHub één keer uit en verplaats het intacte bestand **LivePhotoStudio.ipa** naar een zichtbare locatie in Bestanden. |
| **Untrusted Developer** of app opent niet | Controleer het vertrouwde ontwikkelaarsprofiel en Ontwikkelaarsmodus. Controleer in **My Apps** of de ondertekening vernieuwd moet worden. |
| Foto’s weigert opslag | Geef Live Photo Studio toestemming om foto’s toe te voegen. Als een korte video werkt en een lange video door iOS wordt afgewezen, noteer de iOS-versie, videoduur en precieze fout. |

[AltStore-probleemoplosser](https://faq.altstore.io/altstore-classic/troubleshooting-guide) · [AltStore-foutcodes](https://faq.altstore.io/altstore-classic/error-codes)
