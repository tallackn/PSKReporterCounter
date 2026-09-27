import Charts
import PSKReporterCore
import SwiftUI

struct IntervalChartsView: View {
    let snapshot: ListenerSnapshot
    var animate = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ArrivalHistogramView(snapshot: snapshot)
            Divider()
            SignalBoxPlotView(snapshot: snapshot, animate: animate)
        }
    }
}

