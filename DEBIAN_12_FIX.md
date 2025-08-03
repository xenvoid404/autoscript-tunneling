# Perbaikan Masalah Kompatibilitas Debian 12

## Masalah yang Ditemukan

Script autoscript menampilkan error berikut ketika dijalankan di Debian 12:
```
[INFO] Quick installation started...
[ERROR] Debian 11+ required. Current: 12
```

Padahal Debian 12 seharusnya kompatibel karena versi 12 > 11.

## Penyebab Masalah

Masalah terjadi karena penggunaan command `bc -l` untuk membandingkan versi yang tidak reliable:

```bash
# Kode lama yang bermasalah
if [[ $(echo "$VERSION_ID >= 11" | bc -l 2>/dev/null || echo "0") -eq 0 ]]; then
    print_error "Debian 11+ required. Current: $VERSION_ID"
    exit 1
fi
```

## Solusi yang Diterapkan

1. **Mengganti logika perbandingan versi** dengan fungsi `version_compare()` yang lebih robust
2. **Menghilangkan ketergantungan pada package `bc`**
3. **Menggunakan arithmetic comparison bash native**

### Fungsi Baru `version_compare()`

```bash
version_compare() {
    local version1=$1
    local operator=$2  
    local version2=$3
    
    # Convert versions to comparable format (handle major.minor)
    local v1_major=$(echo "$version1" | cut -d. -f1)
    local v1_minor=$(echo "$version1" | cut -d. -f2 2>/dev/null || echo "0")
    local v2_major=$(echo "$version2" | cut -d. -f1)
    local v2_minor=$(echo "$version2" | cut -d. -f2 2>/dev/null || echo "0")
    
    # Handle fractional parts properly
    if [[ "$v1_minor" =~ ^[0-9]+$ ]] && [[ ${#v1_minor} -eq 1 ]]; then
        v1_minor=$((v1_minor * 10))  # 9 becomes 90
    fi
    if [[ "$v2_minor" =~ ^[0-9]+$ ]] && [[ ${#v2_minor} -eq 1 ]]; then
        v2_minor=$((v2_minor * 10))  # 9 becomes 90
    fi
    
    local v1_int=$((v1_major * 100 + v1_minor))
    local v2_int=$((v2_major * 100 + v2_minor))
    
    case $operator in
        ">=") [[ $v1_int -ge $v2_int ]] ;;
        ">")  [[ $v1_int -gt $v2_int ]] ;;
        "=")  [[ $v1_int -eq $v2_int ]] ;;
        "<")  [[ $v1_int -lt $v2_int ]] ;;
        "<=") [[ $v1_int -le $v2_int ]] ;;
        *)    return 1 ;;
    esac
}
```

### Penggunaan Baru

```bash
# Kode baru yang sudah diperbaiki
if ! version_compare "$VERSION_ID" ">=" "11"; then
    print_error "Debian 11+ required. Current: $VERSION_ID"
    exit 1
fi
```

## File yang Diperbaiki

1. `quick-install.sh` - Script instalasi cepat
2. `install.sh` - Script instalasi utama  
3. `utils/common.sh` - Utility functions

## Testing

Fungsi telah ditest dengan berbagai skenario:

- ✅ Debian 12 >= 11 → TRUE
- ✅ Debian 11 >= 11 → TRUE
- ✅ Debian 10 >= 11 → FALSE
- ✅ Ubuntu 25.04 >= 22.04 → TRUE
- ✅ Ubuntu 22.04 >= 22.04 → TRUE
- ✅ Ubuntu 20.04 >= 22.04 → FALSE

## Manfaat Perbaikan

1. **Kompatibilitas yang benar** - Debian 12 sekarang dapat menginstall script
2. **Menghilangkan dependency `bc`** - Tidak perlu install package tambahan
3. **Performa lebih baik** - Menggunakan bash arithmetic native
4. **Lebih robust** - Handle berbagai format versi dengan benar
5. **Maintainability** - Kode lebih mudah dipahami dan debug

## Verifikasi

Untuk memverifikasi perbaikan, jalankan script di sistem Debian 12. Script tidak akan lagi menampilkan error compatibility dan akan melanjutkan ke proses instalasi.