exports.isValidEmail = (email) => {
  const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return regex.test(email);
};

exports.isStrongPassword = (password) => {
  return password.length >= 6;
};

exports.isValidPhone = (phone) => {
  return /^[0-9]{10,15}$/.test(phone);
};

exports.isNonEmpty = (value) => {
  return value && value.trim().length > 0;
};

exports.isRatingValid = (rating) => {
  return rating >= 1 && rating <= 5;
};
