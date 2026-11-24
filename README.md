# Live Photo Studio

Een gratis, native iPhone-app die van een video één Apple Live Photo maakt. De app verwerkt je video lokaal en gebruikt geen advertenties, watermerken, accounts of aankopen. Vereist iOS 17 of nieuwer.

**Import Video → Convert to Live Photo → Save Live Photo**

1. Importeer een MP4- of MOV-video vanuit Apple Foto’s of Bestanden. De app toont het videovoorbeeld met de bronduur.
2. Kies eventueel een hoofdframe. Zonder keuze gebruikt de app het midden van het videospoor. Tik op **Convert to Live Photo**. Na conversie kun je het resultaat afspelen via de afspeelknop naast het Live Photo-voorbeeld als iOS het voorbeeld opent.
3. Tik op **Save Live Photo** en geef zo nodig toestemming om toe te voegen aan Foto’s. De app toont **Live Photo opgeslagen in Foto’s** zodra PhotoKit de transactie bevestigt.

## Installeren met Windows

Volg de [Nederlandstalige installatiehandleiding voor AltStore Classic](docs/INSTALLATIE-WINDOWS.md). De [GitHub Actions-workflow](.github/workflows/ios.yml) bouwt een unsigned arm64-IPA voor een fysieke iPhone. Deze staat bij **Artifacts** van de [build op GitHub Actions](https://github.com/zitoun-spec/LivePhotoStudio-iOS/actions) als **LivePhotoStudio**. AltStore Classic ondertekent het IPA met je gratis Apple Account.

## Lange video’s

De app heeft geen maximale videoduur en knipt geen fragmenten. AVFoundation kopieert de gecomprimeerde samples van het actieve H.264- of HEVC-videospoor en de audiosporen naar een MOV, met de oorspronkelijke oriëntatie en zonder hercodering. ImageIO schrijft het hoofdframe als JPEG met dezelfde Apple-assetidentifier als de MOV. Een QuickTime-metadataspoor markeert de positie van het gekozen frame. De app controleert de duur en de tijdgrenzen van de sporen voor opslag. Als de tijdlijn niet behouden kan blijven, stopt de conversie met een fout.

Apple beschrijft ongeveer drie seconden voor Live Photos die de iPhone-camera maakt. Apple publiceert in de gebruikte PhotoKit-documentatie geen gegarandeerde maximale invoerduur of afspeelduur voor zelf samengestelde Live Photos. iOS kan het voorbeeld of de opslag afwijzen, en een succesvol opgeslagen Live Photo kan in Foto’s korter afspelen dan de gekoppelde MOV. De app meldt een afgewezen voorbeeld of opslag en probeert geen ingekorte versie. [Apple over Live Photos maken](https://support.apple.com/nl-nl/104966) · [Apple over de werking van PhotoKit bij opslag](https://developer.apple.com/documentation/avfoundation/capturing-and-saving-live-photos) · [Apple over het laden van een lokaal Live Photo-voorbeeld](https://developer.apple.com/documentation/photos/phlivephoto/request(withresourcefileurls:placeholderimage:targetsize:contentmode:resulthandler:))

## Bouwen en testen

Open `LivePhotoStudio.xcodeproj` in Xcode 16.4 of nieuwer en kies het gedeelde schema **LivePhotoStudio**. Het project gebruikt SwiftUI, AVFoundation, ImageIO, PhotoKit en PhotosUI, zonder externe Swift-packages.

De geautomatiseerde tests gebruiken synthetische testvideo’s van 2,5, 12, 35,5 en 65 seconden. Ze controleren de duur, het hoofdframe, gekoppelde identifiers, getimede metadata en het aantal en de SHA-256-hash van gecomprimeerde video- en audiosamples. Een staande video test ook de oriëntatie. De [testprocedure voor een fysieke iPhone](docs/TESTEN-IPHONE.md) controleert import, opslag en de daadwerkelijk afgespeelde duur in Apple Foto’s.

De bronvideo en de twee gekoppelde bronnen worden tijdelijk in de afgeschermde appcache bewaard. Een nieuwe import of nieuwe conversie ruimt vervangen bestanden op. Een nieuwe app-sessie ruimt de cache van eerdere sessies op. iOS kan een geselecteerde cloudvideo eerst lokaal ophalen via Foto’s of Bestanden. Als je iCloud-foto’s gebruikt, kan Apple Foto’s het opgeslagen exemplaar met je iCloud-bibliotheek synchroniseren.
