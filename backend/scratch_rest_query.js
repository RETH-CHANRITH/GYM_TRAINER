const http = require('https');

function getJSON(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', (err) => {
      reject(err);
    });
  });
}

async function run() {
  try {
    console.log("=== GETTING REVIEWS VIA REST ===");
    const reviewsData = await getJSON('https://firestore.googleapis.com/v1/projects/gym-trainer-booking-app/databases/(default)/documents/reviews');
    if (reviewsData.documents) {
      console.log(`Found ${reviewsData.documents.length} reviews:`);
      reviewsData.documents.forEach(doc => {
        const fields = doc.fields;
        console.log(`- Review: TrainerId: ${fields.trainerId?.stringValue}, Rating: ${fields.rating?.doubleValue || fields.rating?.integerValue}, Comment: ${fields.comment?.stringValue}, User: ${fields.userName?.stringValue}`);
      });
    } else {
      console.log("No reviews found or REST API call empty.", reviewsData);
    }
  } catch (err) {
    console.error("REST Error:", err.message);
  }
}

run();
