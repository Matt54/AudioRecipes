import SwiftUI

struct SpectrumPopupView: View {
    
    // TODO: geo reader for padding and corner radius
    
    @Binding var frequency : Double
    
    //var note: String = "a"
    
    @Binding var amplitude : Double
    
    @State var colorForeground = Color.yellow
    
    var body: some View {
        var ampString = ""
        var freqString = ""
        var noteString = ""
        
        var freqDisplayed = frequency
        
        var freqUnits = "  Hz"
        if(frequency > 999) {
            freqDisplayed = frequency / 1000.0
            freqUnits = "kHz"
        }
        
        freqString = getThreeCharacters(freqDisplayed)
        ampString = getThreeCharacters(amplitude, isNegative: true)
        noteString = calculateNote(Float(frequency))
        if noteString.count < 3 {
            noteString = "  " + calculateNote(Float(frequency))
        }
        
        return //ZStack{
            //GeometryReader{ geo in
                //Rectangle()
                //    .foregroundColor(colorForeground)
                    //.cornerRadius(geo.size.width * 0.1)
                
                /*VStack(spacing: 0.0){
                    Spacer()
                    HStack{
                        Spacer()
                        Rectangle()
                            .frame(width: geo.size.width * 0.95, height: geo.size.height * 0.95)
                            .cornerRadius(geo.size.width * 0.08)
                        Spacer()
                    }
                    Spacer()
                }*/
                
                VStack(spacing: 0.0){
                    Text(freqString + " " + freqUnits)
                    Text("          " + noteString)
                    Text(ampString + "  db")
                }
                .font(.headline)
                .foregroundColor(colorForeground)
                .padding(5)
                .background(Color.black)
                .cornerRadius(10)
                
                /*.padding(geo.size.width * 0.05)
                .font(.system(size: 500))
                .minimumScaleFactor(0.01)*/
            //}
        //}
    }
}

func getThreeCharacters(_ value: Double, isNegative: Bool = false) -> String {
    if !isNegative{
        if value < 10.0  {
            return String(format: "%.2f", value)
        } else if value < 100.0 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.0f", value)
        }
    } else {
        if value < -100.0  {
            return String(format: "%.0f", value)
        } else if value < -10.0 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

func calculateNote(_ pitch: Float) -> String {
    
    let noteFrequencies = [16.35, 17.32, 18.35, 19.45, 20.6, 21.83, 23.12, 24.5, 25.96, 27.5, 29.14, 30.87]
    let noteNamesWithSharps = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    
    var frequency = pitch
    while frequency > Float(noteFrequencies[noteFrequencies.count - 1]) {
        frequency /= 2.0
    }
    while frequency < Float(noteFrequencies[0]) {
        frequency *= 2.0
    }

    var minDistance: Float = 10_000.0
    var index = 0

    for possibleIndex in 0 ..< noteFrequencies.count {
        let distance = fabsf(Float(noteFrequencies[possibleIndex]) - frequency)
        if distance < minDistance {
            index = possibleIndex
            minDistance = distance
        }
    }
    let octave = Int(log2f(pitch / frequency))
    return "\(noteNamesWithSharps[index])\(octave)"
    //data.noteNameWithSharps = "\(noteNamesWithSharps[index])\(octave)"
}

struct SpectrumPopupView_Previews: PreviewProvider {
    static var previews: some View {
        SpectrumPopupView(frequency: .constant(100.1), amplitude: .constant(-100.1))
            //.frame(width: 400, height: 400)
    }
}
