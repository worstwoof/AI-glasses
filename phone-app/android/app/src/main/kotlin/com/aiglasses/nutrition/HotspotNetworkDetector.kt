package com.aiglasses.nutrition

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import org.webrtc.NetworkChangeDetector
import org.webrtc.NetworkChangeDetector.ConnectionType
import org.webrtc.NetworkChangeDetector.IPAddress
import org.webrtc.NetworkChangeDetector.NetworkInformation
import org.webrtc.NetworkChangeDetector.NetworkSlice
import org.webrtc.NetworkMonitor
import org.webrtc.NetworkMonitorAutoDetect
import java.net.Inet4Address
import java.net.NetworkInterface
import java.util.Collections

/** Adds a tethering Wi-Fi interface which ConnectivityManager does not report.
 * Normal Wi-Fi/cellular callbacks remain owned by WebRTC's standard detector.
 */
class HotspotNetworkDetector(
    private val observer: NetworkChangeDetector.Observer,
    context: Context,
) : NetworkChangeDetector {
    private val delegate = NetworkMonitorAutoDetect(observer, context)
    private val handler = Handler(Looper.getMainLooper())
    @Volatile private var destroyed = false
    private var lastLogged: String? = null
    @Volatile private var supplemental: NetworkInformation? = findMissingWifi(delegate.activeNetworkList.orEmpty())
    private val poll = object : Runnable {
        override fun run() {
            synchronized(this@HotspotNetworkDetector) {
                if (destroyed) return
                val next = findMissingWifi(delegate.activeNetworkList.orEmpty())
                if (signature(next) != signature(supplemental)) {
                    if (supplemental != null) observer.onNetworkDisconnect(LOCAL_NETWORK_HANDLE)
                    supplemental = next
                    if (next != null) observer.onNetworkConnect(next)
                    observer.onConnectionTypeChanged(getCurrentConnectionType())
                }
                handler.postDelayed(this, 2000)
            }
        }
    }

    init { handler.postDelayed(poll, 2000) }

    override fun getCurrentConnectionType(): ConnectionType =
        if (supplemental != null) ConnectionType.CONNECTION_WIFI else delegate.currentConnectionType

    override fun supportNetworkCallback() = true

    @Synchronized
    override fun getActiveNetworkList(): List<NetworkInformation> =
        delegate.activeNetworkList.orEmpty() + listOfNotNull(supplemental)

    @Synchronized
    override fun destroy() {
        destroyed = true
        handler.removeCallbacks(poll)
        delegate.destroy()
    }

    private fun findMissingWifi(known: List<NetworkInformation>): NetworkInformation? {
        // Handle 0 is NETWORK_UNSPECIFIED, as used by WebRTC's Wi-Fi Direct
        // detector. Do not invent a ConnectivityManager network handle or bind
        // the entire process: HTTPS AI calls must still use mobile data.
        if (known.any { it.handle == LOCAL_NETWORK_HANDLE }) return null
        return try {
            val interfaces = Collections.list(NetworkInterface.getNetworkInterfaces())
            val network = interfaces.firstOrNull { candidate ->
                isWifiInterface(candidate.name) && candidate.isUp && !candidate.isLoopback &&
                    known.none { it.name == candidate.name } &&
                    Collections.list(candidate.inetAddresses).any { it is Inet4Address && it.isSiteLocalAddress }
            } ?: return null
            val addresses = Collections.list(network.inetAddresses)
                .filter { it is Inet4Address && it.isSiteLocalAddress }
            NetworkInformation(
                network.name, ConnectionType.CONNECTION_WIFI, ConnectionType.CONNECTION_NONE,
                LOCAL_NETWORK_HANDLE, addresses.map { IPAddress(it.address) }.toTypedArray(),
                NetworkSlice.NO_SLICE,
            ).also {
                val value = signature(it)
                if (value != lastLogged) {
                    Log.i(TAG, "supplemental interface=$value")
                    lastLogged = value
                }
            }
        } catch (error: Exception) {
            Log.w(TAG, "Cannot enumerate hotspot interface", error)
            null
        }
    }

    private fun signature(info: NetworkInformation?): String? = info?.let {
        it.name + ":" + it.ipAddresses.joinToString { address ->
            address.address.joinToString(".") { byte -> (byte.toInt() and 255).toString() }
        }
    }

    companion object {
        private const val TAG = "HotspotNetworkDetector"
        private const val LOCAL_NETWORK_HANDLE = 0L
        private var installed = false

        fun isWifiInterface(name: String) =
            name.startsWith("wlan") || name.startsWith("ap") || name.startsWith("swlan")

        @Synchronized fun install() {
            if (installed) return
            NetworkMonitor.getInstance().setNetworkChangeDetectorFactory { observer, context ->
                HotspotNetworkDetector(observer, context)
            }
            installed = true
        }
    }
}
