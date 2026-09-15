use rand::Rng;

fn main() {
    const N: usize = 16_777_216;
    let bios: &'static [u8; N] = include_bytes!("../VANILA.CAP");
    let mut bios: Vec<u8> = bios.try_into().unwrap();
    let mut rng = rand::rng();
    // random mac addr
    for i in 0..3 {
        bios[4099 + i] = rng.random_range(0..256) as u8;
    }
    
    // random uuid
    for index in vec![5652541, 6357182] {
        for i in 0..10 {
            bios[index + i] = rng.random_range(0..256) as u8;
        }
    }
    
    // random serial number
    for index in vec![5652509, 6357161] {
        for i in 0..11 {
            bios[index + i] = rng.random_range(48..58) as u8;
        }
    }
    
    std::fs::write("GENERATED-BIOS.BIN", bios).unwrap();
}
